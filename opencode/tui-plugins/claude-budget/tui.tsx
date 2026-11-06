/** @jsxImportSource @opentui/solid */
// Claude budget for opencode 2: the sidebar block from index.tsx (opencode 1), same core.ts and the same
// cache file. opencode 2 keeps credentials in its database and never writes auth.json, so the token comes
// from the server's credential list instead. Loaded from cli.json as a directory: "./tui-plugins/claude-budget".
import { createSignal, ErrorBoundary, Show } from "solid-js"
import { Plugin } from "@opencode/plugin/tui"
import { mkdir, readFile, rename, writeFile } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import { ago, type Cache, isDue, parseCache, parseUsage, readToken, retryAfter, summarize } from "./core.ts"

// Undocumented: the endpoint behind Claude Code's /usage. URL and beta header as requested by
// sirmalloc/ccstatusline (src/utils/usage-fetch.ts) and slkiser/opencode-quota (src/lib/anthropic.ts),
// and checked against a live Claude Enterprise seat on 2026-11-04.
const USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
const USAGE_BETA = "oauth-2025-04-20"
const TICK = 60_000 // re-read the shared cache and refresh "updated Xm ago" every minute
const TIMEOUT = 15_000
const CACHE_FILE = path.join(
  process.env.XDG_STATE_HOME || path.join(os.homedir(), ".local/state"),
  "opencode",
  "claude-budget.json",
)
type Context = Plugin.Context

async function readJson(file: string): Promise<unknown> {
  try {
    return JSON.parse(await readFile(file, "utf8"))
  } catch {
    return null
  }
}

// Only numbers and a short status ever go in here, never the token.
async function writeCache(cache: Cache) {
  await mkdir(path.dirname(CACHE_FILE), { recursive: true })
  const tmp = `${CACHE_FILE}.${process.pid}.tmp`
  await writeFile(tmp, JSON.stringify(cache))
  await rename(tmp, CACHE_FILE)
}

// The auth.json shape core.readToken() expects, from the freshest Anthropic OAuth credential: an imported
// opencode 1 token can sit next to the one the opencode 2 auth plugin refreshes.
async function readAuth(client: Context["client"]): Promise<unknown> {
  const all = (await client.credential.list().catch(() => [])).filter((c) => c.integrationID === "anthropic")
  const oauth = all
    .flatMap((c) => (c.value.type === "oauth" ? [c.value] : []))
    .sort((a, b) => b.expires - a.expires)[0]
  if (oauth) return { anthropic: oauth }
  return all.length ? { anthropic: { type: "api" } } : null
}

async function fetchUsage(prev: Cache | null, signal: AbortSignal, client: Context["client"]): Promise<Cache> {
  const now = Date.now()
  const keep: Cache = {
    v: 1,
    budget: prev?.budget ?? null,
    fetchedAt: prev?.fetchedAt ?? 0,
    attemptedAt: now,
    ...(prev?.retryAt !== undefined ? { retryAt: prev.retryAt } : {}),
  }
  const token = readToken(await readAuth(client), now)
  // No request is made, so no throttling either: the next tick asks the server again.
  if ("reason" in token) return { ...keep, attemptedAt: prev?.attemptedAt ?? 0, error: token.reason }
  if (signal.aborted) return { ...keep, attemptedAt: prev?.attemptedAt ?? 0 }

  // Claim the attempt before the request, so windows that start together do not all fetch.
  await writeCache(keep)
  if (signal.aborted) return keep // disposed while claiming: no request after shutdown

  const ctrl = new AbortController()
  const stop = () => ctrl.abort()
  signal.addEventListener("abort", stop, { once: true })
  const timer = setTimeout(stop, TIMEOUT)
  try {
    const res = await fetch(USAGE_URL, {
      headers: { authorization: `Bearer ${token.access}`, "anthropic-beta": USAGE_BETA },
      signal: ctrl.signal,
    })
    if (res.status === 429) {
      return { ...keep, retryAt: retryAfter(res.headers.get("retry-after"), now), error: "rate limited" }
    }
    if (!res.ok) return { ...keep, error: `HTTP ${res.status}` }
    let body: unknown
    try {
      body = await res.json()
    } catch {
      return { ...keep, error: "bad response" }
    }
    const budget = parseUsage(body)
    if (!budget) return { ...keep, error: "no spend cap on this account" }
    return { v: 1, budget, fetchedAt: now, attemptedAt: now }
  } catch {
    return { ...keep, error: signal.aborted ? "stopped" : "network error" }
  } finally {
    clearTimeout(timer)
    signal.removeEventListener("abort", stop)
  }
}

type ViewProps = { ctx: Context; cache: () => Cache | null; now: () => number }

function View(props: ViewProps) {
  const theme = () => props.ctx.theme // read inside JSX so theme switches apply
  const summary = () => {
    const budget = props.cache()?.budget
    return budget ? summarize(budget, new Date(props.now())) : null
  }
  const color = () => {
    const level = summary()?.level ?? 0
    const text = theme().text
    return level === 2 ? text.feedback.error.base : level === 1 ? text.feedback.warning.base : text.muted
  }
  const status = () => {
    const cache = props.cache()
    if (!cache) return "loading"
    const age = cache.fetchedAt ? `updated ${ago(props.now() - cache.fetchedAt)}` : "no data yet"
    return cache.error ? `${cache.error} · ${age}` : age
  }

  return (
    <box>
      <text fg={theme().text.base}>
        <b>Claude budget</b>
      </text>
      <Show when={summary()}>
        {(s) => (
          <box>
            <text fg={color()}>
              {s().amount} ({s().percent})
            </text>
            <text fg={theme().text.muted}>{s().pace}</text>
          </box>
        )}
      </Show>
      <text fg={theme().text.muted}>{status()}</text>
    </box>
  )
}

export default Plugin.define({
  id: "claude-budget",
  setup(ctx) {
    const stop = new AbortController() // opencode 1: api.lifecycle.signal
    const [cache, setCache] = createSignal<Cache | null>(null)
    const [now, setNow] = createSignal(Date.now())
    let busy = false

    const tick = async () => {
      if (busy) return
      busy = true
      try {
        if (stop.signal.aborted) return
        setNow(Date.now())
        const shared = parseCache(await readJson(CACHE_FILE))
        if (shared) setCache(shared)
        if (!isDue(shared, Date.now())) return
        const next = await fetchUsage(shared, stop.signal, ctx.client)
        if (stop.signal.aborted) return
        setCache(next)
        await writeCache(next)
      } catch {
        // A failed poll must never reach the TUI; the status line shows the last known state.
      } finally {
        busy = false
      }
    }

    void tick()
    const timer = setInterval(() => void tick(), TICK)

    // opencode 1 sat between Context and MCP (order 150); opencode 2 only offers prepend or append.
    ctx.ui.slot({
      append: "sidebar.content",
      render: () => (
        <ErrorBoundary fallback={<text fg={ctx.theme.text.muted}>Claude budget: display error</text>}>
          <View ctx={ctx} cache={cache} now={now} />
        </ErrorBoundary>
      ),
    })

    return () => {
      clearInterval(timer)
      stop.abort()
    } // opencode 1: api.lifecycle.onDispose
  },
})
