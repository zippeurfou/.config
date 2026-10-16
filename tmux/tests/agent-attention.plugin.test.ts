// Tests for the opencode plugin ~/.config/opencode/plugins/agent-attention.ts:
// what it tells tmux for each sequence of opencode events.
// Run (from ~/.config): bun test ./tmux/tests/agent-attention.plugin.test.ts
//
// HOME points at a temp dir holding a fake scripts/agent-attention.sh that only
// logs its arguments, so no tmux server is involved. The plugin calls the
// script synchronously, so every call is logged by the time an event returns.
import { expect, test } from "bun:test"
import { spawnSync } from "node:child_process"
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const PLUGIN = join(import.meta.dir, "../../opencode/plugins/agent-attention.ts")

let log = ""

// A fresh fake HOME whose agent-attention.sh appends its arguments to `log`.
function fakeHome(): string {
  const home = mkdtempSync(join(tmpdir(), "agent-attention-"))
  const dir = join(home, ".config/tmux/scripts")
  mkdirSync(dir, { recursive: true })
  log = join(home, "calls.log")
  writeFileSync(join(dir, "agent-attention.sh"), `#!/bin/sh\necho "$*" >> '${log}'\n`)
  chmodSync(join(dir, "agent-attention.sh"), 0o755)
  return home
}

const calls = () =>
  existsSync(log) ? readFileSync(log, "utf8").split("\n").filter(Boolean) : []

// Load the plugin as opencode would, inside tmux pane %7 (or outside tmux).
async function plugin(inTmux = true) {
  process.env.HOME = fakeHome()
  if (inTmux) {
    process.env.TMUX = "/tmp/tmux-fake/default,1,0"
    process.env.TMUX_PANE = "%7"
  } else {
    delete process.env.TMUX
    delete process.env.TMUX_PANE
  }
  const { AgentAttention } = await import(PLUGIN)
  const hooks = await AgentAttention({} as any)
  const send = async (type: string, properties: object) => hooks.event?.({ event: { type, properties } } as any)
  return { hooks, send }
}

const status = (sessionID: string, type: string) => ["session.status", { sessionID, status: { type } }] as const

// Break: no busy/waiting at all, or waiting before the turn ends.
test("a turn: busy while it works, waiting when it ends", async () => {
  const { send } = await plugin()
  await send(...status("s1", "busy"))
  await send(...status("s1", "idle"))
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting"])
})

// Break: a session that was never busy (opencode just started) lights the dot.
test("idle at startup, before any work, tells nothing", async () => {
  const { send } = await plugin()
  await send(...status("s1", "idle"))
  await send("session.idle", { sessionID: "s1" })
  expect(calls()).toEqual(["set %7 clear"])
})

// Break: the same state is sent again, which would re-light a dot you already saw.
test("repeated busy and idle events tell tmux once each", async () => {
  const { send } = await plugin()
  await send(...status("s1", "busy"))
  await send(...status("s1", "retry"))
  await send(...status("s1", "busy"))
  await send(...status("s1", "idle"))
  await send("session.idle", { sessionID: "s1" })
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting"])
})

// Break: a subagent finishing mid-turn reports waiting while the main session works.
test("subagents: waiting only once the main session is done too", async () => {
  const { send } = await plugin()
  await send(...status("main", "busy"))
  await send(...status("sub", "busy"))
  await send(...status("sub", "idle")) // subagent done, main still working
  await send(...status("main", "busy"))
  await send(...status("main", "idle"))
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting"])
})

// Break: a permission prompt mid-turn doesn't count as waiting, or answering it
// leaves the dot on while the agent works again.
test("a permission prompt is waiting; answering it is busy again", async () => {
  const { send } = await plugin()
  await send(...status("s1", "busy"))
  await send("permission.asked", { id: "p1", sessionID: "s1" })
  await send("permission.replied", { sessionID: "s1", requestID: "p1", reply: "once" })
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting", "set %7 busy"])
})

// Break: the older reply shape (permissionID instead of requestID) is ignored.
test("a permission reply with the older permissionID field works too", async () => {
  const { send } = await plugin()
  await send(...status("s1", "busy"))
  await send("permission.asked", { id: "p1", sessionID: "s1" })
  await send("permission.replied", { sessionID: "s1", permissionID: "p1", response: "once" })
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting", "set %7 busy"])
})

// Break: questions (the question tool) don't count, or rejecting one leaves the dot on.
test("a question is waiting; rejecting it is busy again", async () => {
  const { send } = await plugin()
  await send(...status("s1", "busy"))
  await send("question.asked", { id: "q1", sessionID: "s1", questions: [] })
  await send("question.rejected", { sessionID: "s1", requestID: "q1" })
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting", "set %7 busy"])
})

// Break: with two prompts open, answering one reports busy while the other still waits.
test("two open prompts: still waiting until both are answered", async () => {
  const { send } = await plugin()
  await send(...status("s1", "busy"))
  await send("permission.asked", { id: "p1", sessionID: "s1" })
  await send("question.asked", { id: "q1", sessionID: "s2", questions: [] })
  await send("permission.replied", { sessionID: "s1", requestID: "p1", reply: "once" })
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting"])
  await send("question.replied", { sessionID: "s2", requestID: "q1", answers: [] })
  expect(calls()).toEqual(["set %7 clear", "set %7 busy", "set %7 waiting", "set %7 busy"])
})

// Break: the plugin runs (and fails) outside tmux, e.g. opencode in a plain terminal.
test("outside tmux it does nothing", async () => {
  const { hooks } = await plugin(false)
  expect(hooks).toEqual({})
  expect(calls()).toEqual([])
})

// Break: quitting opencode leaves its pane marked, so the dot stays on.
test("quitting opencode clears its pane", () => {
  const home = fakeHome()
  const driver = `const { AgentAttention } = await import(${JSON.stringify(PLUGIN)}); await AgentAttention({}); process.exit(0)`
  const run = spawnSync(process.execPath, ["-e", driver], {
    env: { ...process.env, HOME: home, TMUX: "/tmp/tmux-fake/default,1,0", TMUX_PANE: "%7" },
    encoding: "utf8",
  })
  expect(run.status).toBe(0)
  expect(calls()).toEqual(["set %7 clear", "set %7 clear"]) // on start, then on exit
})
