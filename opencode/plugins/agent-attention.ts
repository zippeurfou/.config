// Tells tmux when this opencode needs you, for the "● N" dot and the Cmd+Up jump
// in ~/.config/tmux (agent-attention.conf, scripts/agent-attention.sh). Inside a
// tmux pane it reports one of three states for that pane:
//   busy     a turn is running (the main session or any of its subagents)
//   waiting  the turn ended, or a permission/question prompt is open
//   clear    opencode just started or is quitting
// tmux takes it from there: "waiting" lights the dot unless you're looking at the
// pane, and visiting the pane marks it seen. Outside tmux it does nothing.
// Tests: ~/.config/tmux/tests/agent-attention.plugin.test.ts
//
// Keep a single export: opencode loads every exported function here as a plugin.
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
