// Tells tmux when this opencode needs you, for the "● N" dot and the Cmd+Up jump
// in ~/.config/tmux (agent-attention.conf, scripts/agent-attention.sh). Inside a
// tmux pane it reports one of three states for that pane:
//   busy     a turn is running (the main session or any of its subagents)
//   waiting  the turn ended, or a permission/question prompt is open
//   clear    opencode just started or is quitting
// tmux takes it from there: "waiting" lights the dot unless you're looking at the
// pane, and visiting the pane marks it seen. Outside tmux it does nothing.
// Tests: ~/.config/tmux/tests/agent-attention.plugin.test.ts (opencode 1 part)
//        ~/.config/tmux/tests/agent-attention.tui.test.ts (opencode 2 part)
//
// One file for opencode 1 and 2. opencode 1 sees the default export object, so it
// calls `server` once and never scans the named exports: keep that object, or
// opencode 1 loads every exported function here as a plugin. Its bundled v2 core
// also calls `setup`, without events, so `setup` stays a no-op. opencode 2 runs
// server plugins in a background service whose TMUX_PANE is whichever pane started
// it, so the per-pane work is AgentAttentionTui, loaded by plugins/agent-attention/
// tui.ts inside each pane's own TUI process.
import type { Plugin } from "@opencode-ai/plugin"
import { spawnSync } from "node:child_process"
import { homedir } from "node:os"
import { join } from "node:path"

export const AgentAttention: Plugin = async () => {
  const pane = process.env.TMUX_PANE
  if (!pane || !process.env.TMUX) return {}
  // $HOME first: Bun's homedir() is fixed at startup and ignores later changes.
  const script = join(process.env.HOME || homedir(), ".config", "tmux", "scripts", "agent-attention.sh")

  // Synchronous on purpose: state changes are rare (a few per turn), the script
  // takes milliseconds, and this keeps them in order. The timeout bounds a hung tmux.
  const tell = (state: string) => {
    try {
      spawnSync(script, ["set", pane, state], { stdio: "ignore", timeout: 2000 })
    } catch {}
  }

  const working = new Set<string>() // sessions mid-turn: the main one and its subagents
  const asking = new Set<string>() // open permission and question prompts
  let told = ""
  const show = (state: "busy" | "waiting") => {
    if (state === told) return // never repeat a state: that would re-light a dot you saw
    told = state
    tell(state)
  }
  const done = (sessionID: string) => {
    if (working.delete(sessionID) && working.size === 0 && asking.size === 0) show("waiting")
  }

  tell("clear") // a crashed earlier run may have left this pane marked
  process.on("exit", () => tell("clear"))

  return {
    event: async ({ event }) => {
      try {
        const p = (event as { properties?: Record<string, any> }).properties ?? {}
        switch (event.type as string) {
          case "session.status":
            if (p.status?.type === "idle") done(p.sessionID)
            else {
              working.add(p.sessionID) // busy or retry
              if (asking.size === 0) show("busy")
            }
            break
          case "session.idle":
            done(p.sessionID)
            break
          case "permission.asked":
          case "question.asked":
            asking.add(p.id)
            show("waiting")
            break
          case "permission.replied":
          case "question.replied":
          case "question.rejected":
            asking.delete(p.requestID ?? p.permissionID) // permissionID: older event shape
            if (asking.size === 0 && working.size > 0) show("busy")
            break
        }
      } catch {}
    },
  }
}

// opencode 2, inside this pane's TUI. The same three states, from v2 events:
// session.execution.* and session.retry.scheduled (a turn), permission.asked/replied,
// form.created/replied/cancelled (the question tool opens forms). The event stream
// carries every session on the server, so only sessions this TUI has shown count,
// with subagents folded into their root session. Not the tab list: tabs are stored
// per working directory and shared by every TUI started there, so a tab can belong
// to another pane.
export const SETTLE_MS = 1500
export const AgentAttentionTui = {
  id: "agent-attention-tui",
  setup(ctx: any) {
    const pane = process.env.TMUX_PANE
    if (!pane || !process.env.TMUX) return
    const script = join(process.env.HOME || homedir(), ".config", "tmux", "scripts", "agent-attention.sh")
    const tell = (state: string) => {
      try {
        spawnSync(script, ["set", pane, state], { stdio: "ignore", timeout: 2000 })
      } catch {}
    }

    const working = new Set<string>() // sessions mid-turn: the root one and its subagents
    const asking = new Set<string>() // open permission and question prompts
    let told = ""
    let idle: ReturnType<typeof setTimeout> | undefined
    const show = (state: "busy" | "waiting") => {
      clearTimeout(idle)
      if (state === told) return // never repeat a state: that would re-light a dot you saw
      told = state
      tell(state)
    }
    // v2 runs subagents in background child sessions whose report wakes the parent, so a
    // turn can look finished for a moment: wait briefly before "waiting"; new work cancels it.
    const settle = () => {
      if (working.size || asking.size) return
      clearTimeout(idle)
      idle = setTimeout(() => show("waiting"), SETTLE_MS)
    }

    const root = (id: string): string => ctx.data.session.root(id)
    const shown = new Set<string>() // root sessions this pane has displayed
    const mine = (id?: string) => {
      const route = ctx.ui.router.current()
      if (route?.type === "session") shown.add(root(route.sessionID))
      return !!id && shown.has(root(id))
    }
    const on = (type: string, session: (d: any) => string | undefined, fn: (d: any) => void) =>
      ctx.data.on(type, (event: any) => {
        try {
          if (mine(session(event.data))) fn(event.data)
        } catch {}
      })

    const start = (d: any) => {
      working.add(d.sessionID)
      if (asking.size === 0) show("busy")
    }
    const end = (d: any) => {
      if (working.delete(d.sessionID)) settle()
    }
    const ask = (id: string) => {
      asking.add(id)
      show("waiting")
    }
    const answer = (id: string) => {
      if (!asking.delete(id) || asking.size) return
      if (working.size) show("busy")
      else settle()
    }

    const clear = () => tell("clear")
    clear() // a crashed earlier run may have left this pane marked
    process.once("exit", clear)
    const off: Array<() => void> = [
      on("session.execution.started", (d) => d.sessionID, start),
      on("session.retry.scheduled", (d) => d.sessionID, start),
      on("session.execution.succeeded", (d) => d.sessionID, end),
      on("session.execution.failed", (d) => d.sessionID, end),
      on("session.execution.interrupted", (d) => d.sessionID, end),
      on("permission.asked", (d) => d.sessionID, (d) => ask(d.id)),
      on("permission.replied", (d) => d.sessionID, (d) => answer(d.requestID)),
      on("form.created", (d) => d.form?.sessionID, (d) => ask(d.form.id)),
      on("form.replied", (d) => d.sessionID, (d) => answer(d.id)),
      on("form.cancelled", (d) => d.sessionID, (d) => answer(d.id)),
    ]
    return () => {
      off.forEach((stop) => stop())
      clearTimeout(idle)
      process.off("exit", clear)
      clear()
    }
  },
}

export default { id: "agent-attention", server: AgentAttention, setup() {} }
