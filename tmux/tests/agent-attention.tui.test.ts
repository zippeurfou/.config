// Tests for the opencode 2 part of ~/.config/opencode/plugins/agent-attention.ts
// (AgentAttentionTui): what it tells tmux for each sequence of v2 TUI events.
// Run (from ~/.config): bun test ./tmux/tests/agent-attention.tui.test.ts
//
// HOME points at a temp dir holding a fake scripts/agent-attention.sh that only
// logs its arguments, so no tmux server is involved. The TUI context is faked:
// an event registry, session roots, the current route and the open tabs.
import { expect, test } from "bun:test"
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const PLUGIN = join(import.meta.dir, "../../opencode/plugins/agent-attention.ts")

let log = ""

function fakeHome(): string {
  const home = mkdtempSync(join(tmpdir(), "agent-attention-tui-"))
  const dir = join(home, ".config/tmux/scripts")
  mkdirSync(dir, { recursive: true })
  log = join(home, "calls.log")
  writeFileSync(join(dir, "agent-attention.sh"), `#!/bin/sh\necho "$*" >> '${log}'\n`)
  chmodSync(join(dir, "agent-attention.sh"), 0o755)
  return home
}

const calls = () => (existsSync(log) ? readFileSync(log, "utf8").split("\n").filter(Boolean) : [])

type Handler = (event: { type: string; data: any }) => void

// A fake Plugin.Context: `parents` maps child session -> parent, `route` is what the pane shows,
// `tabs` the open root-session tabs.
function fakeCtx(route: { type: string; sessionID?: string }, tabs: string[] = [], parents: Record<string, string> = {}) {
  const handlers = new Map<string, Handler[]>()
  const root = (id: string): string => (parents[id] ? root(parents[id]) : id)
  const ctx = {
    data: {
      on(type: string, fn: Handler) {
        handlers.set(type, [...(handlers.get(type) ?? []), fn])
        return () => handlers.set(type, (handlers.get(type) ?? []).filter((f) => f !== fn))
      },
      session: { root },
    },
    ui: { router: { current: () => route }, tabs: { list: () => tabs.map((sessionID) => ({ sessionID })) } },
  }
  const emit = (type: string, data: any) => (handlers.get(type) ?? []).forEach((fn) => fn({ type, data }))
  const listening = () => [...handlers.values()].reduce((n, list) => n + list.length, 0)
  return { ctx, emit, listening }
}

async function tui(route = { type: "session", sessionID: "s1" }, tabs: string[] = [], parents = {}, inTmux = true) {
  process.env.HOME = fakeHome()
  if (inTmux) {
    process.env.TMUX = "/tmp/tmux-fake/default,1,0"
    process.env.TMUX_PANE = "%7"
  } else {
    delete process.env.TMUX
    delete process.env.TMUX_PANE
  }
  const mod = await import(PLUGIN)
  const fake = fakeCtx(route, tabs, parents)
  const cleanup = mod.AgentAttentionTui.setup(fake.ctx)
  const settle = () => Bun.sleep(mod.SETTLE_MS + 200)
  return { ...fake, cleanup, settle, mod }
}

const started = (sessionID: string) => ["session.execution.started", { sessionID }] as const
const succeeded = (sessionID: string) => ["session.execution.succeeded", { sessionID }] as const

// Break: no busy/waiting at all, or waiting before the turn has settled.
test("a turn: busy while it works, waiting once it has settled", async () => {
  const { emit, settle, cleanup } = await tui()
  emit(...started("s1"))
  emit(...succeeded("s1"))
  expect(calls()).toEqual(["set %7 clear", "set %7 busy"]) // not yet: the settle window is open
  await settle()
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting"])
  cleanup()
})

// Break: a background subagent's report waking the parent makes the dot blink waiting -> busy -> waiting.
test("subagents: one waiting after the parent is woken by the child's report", async () => {
  const { emit, settle, cleanup } = await tui({ type: "session", sessionID: "main" }, [], { sub: "main" })
  emit(...started("main"))
  emit(...started("sub"))
  emit(...succeeded("main")) // the parent's turn ends while the child still runs
  emit(...succeeded("sub"))
  await Bun.sleep(300)
  emit(...started("main")) // woken by the child's report
  emit(...succeeded("main"))
  await settle()
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting"])
  cleanup()
})

// Break: a permission prompt mid-turn doesn't count as waiting, or answering it leaves the dot on.
test("a permission prompt is waiting; answering it is busy again", async () => {
  const { emit, cleanup } = await tui()
  emit(...started("s1"))
  emit("permission.asked", { id: "p1", sessionID: "s1" })
  emit("permission.replied", { sessionID: "s1", requestID: "p1", reply: "once" })
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting", "set %7 busy"])
  cleanup()
})

// Break: the question tool's forms don't count, or cancelling one leaves the dot on.
test("a question (form) is waiting; cancelling it is busy again", async () => {
  const { emit, cleanup } = await tui()
  emit(...started("s1"))
  emit("form.created", { form: { id: "q1", sessionID: "s1", title: "?", fields: [] } })
  emit("form.cancelled", { id: "q1", sessionID: "s1" })
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting", "set %7 busy"])
  cleanup()
})

// Break: with two prompts open, answering one reports busy while the other still waits.
test("two open prompts (one from a subagent): still waiting until both are answered", async () => {
  const { emit, cleanup } = await tui({ type: "session", sessionID: "s1" }, [], { sub: "s1" })
  emit(...started("s1"))
  emit("permission.asked", { id: "p1", sessionID: "s1" })
  emit("form.created", { form: { id: "q1", sessionID: "sub", title: "?", fields: [] } })
  emit("permission.replied", { sessionID: "s1", requestID: "p1", reply: "once" })
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting"])
  emit("form.replied", { id: "q1", sessionID: "sub", answer: {} })
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting", "set %7 busy"])
  cleanup()
})

// Break: the shared event stream makes this pane react to another pane's sessions.
// Tabs are stored per working directory, so another pane's session can sit in this
// pane's tab list: a tab alone never counts, only sessions this pane has shown.
test("another pane's session is ignored, even when it is in the shared tab list", async () => {
  const { emit, settle, cleanup } = await tui({ type: "session", sessionID: "s1" }, ["t1"])
  emit(...started("other"))
  emit(...succeeded("other"))
  emit(...started("t1"))
  emit(...succeeded("t1"))
  await settle()
  expect(calls()).toEqual(["set %7 clear"])
  emit(...started("s1"))
  expect(calls()).toEqual(["set %7 clear", "set %7 busy"])
  cleanup()
})

// Break: navigating to another session makes this pane forget the one still running
// in the background (its subagents report later and would never light the dot).
test("a session shown earlier still counts after navigating away", async () => {
  const route = { type: "session", sessionID: "s1" }
  const { emit, settle, cleanup } = await tui(route, [], { sub: "s1" })
  emit(...started("s1")) // shown while routed
  route.sessionID = "s2" // user switches to another session in this pane
  emit(...started("sub"))
  emit(...succeeded("s1"))
  emit(...succeeded("sub"))
  await settle()
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting"])
  cleanup()
})

// Break: the plugin runs (and fails) outside tmux, e.g. opencode in a plain terminal.
test("outside tmux it does nothing", async () => {
  const { cleanup, listening } = await tui({ type: "home" }, [], {}, false)
  expect(cleanup).toBeUndefined()
  expect(listening()).toBe(0)
  expect(calls()).toEqual([])
})

// Break: quitting the TUI leaves its pane marked, or handlers keep running after cleanup.
test("cleanup clears the pane and stops listening", async () => {
  const { emit, cleanup, listening } = await tui()
  emit(...started("s1"))
  cleanup()
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 clear"])
  expect(listening()).toBe(0)
  emit(...started("s1"))
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 clear"])
})

// Break: opencode 1 loads every named export as a plugin, or its bundled v2 core trips on setup().
test("the default export wires opencode 1 to AgentAttention and keeps setup a no-op", async () => {
  const mod = await import(PLUGIN)
  expect(mod.default.id).toBe("agent-attention")
  expect(mod.default.server).toBe(mod.AgentAttention)
  expect(mod.default.setup({})).toBeUndefined()
})
