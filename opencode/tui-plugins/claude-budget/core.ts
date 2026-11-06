// Pure helpers for the Claude budget sidebar block. No I/O and no opencode imports, so `bun test` can run them.

export type Budget = { used: number; limit: number; currency: string; limitReached: boolean }
export type Summary = { amount: string; percent: string; pace: string; level: 0 | 1 | 2 }

// The cache shared by every opencode window. `v` versions its shape: anything else is ignored.
export type Cache = {
  v: 1
  budget: Budget | null
  fetchedAt: number // last successful fetch
  attemptedAt: number // last network attempt, successful or not
  retryAt?: number // set after a 429
  error?: string
}

export type Token = { access: string } | { reason: string }

export const FETCH_EVERY = 5 * 60_000 // at most about one request per 5 minutes, shared by every window
const MAX_RETRY = 60 * 60_000 // a Retry-After is honoured up to an hour, never longer

type Rec = Record<string, unknown>

const DAY = 86_400_000
const NOT_SIGNED_IN = "not signed in (opencode auth login)"

function rec(value: unknown): Rec | null {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Rec) : null
}

function num(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null
}

// An ISO 4217 code, else USD: Intl.NumberFormat throws on anything else.
function currency(value: unknown): string {
  return typeof value === "string" && /^[A-Za-z]{3}$/.test(value) ? value.toUpperCase() : "USD"
}

// A money object from the spend block: { amount_minor, currency, exponent }.
function money(value: unknown): { amount: number; currency: string } | null {
  const m = rec(value)
  const minor = num(m?.amount_minor)
  if (!m || minor === null) return null
  return { amount: minor / 10 ** (num(m.exponent) ?? 2), currency: currency(m.currency) }
}

// Parses GET https://api.anthropic.com/api/oauth/usage, which is undocumented.
// Prefers the `spend` block and falls back to `extra_usage` (amounts in minor units).
export function parseUsage(json: unknown): Budget | null {
  const root = rec(json)
  if (!root) return null
  const extra = rec(root.extra_usage)
  const limitReached = extra?.spend_limit_reached === true

  const spend = rec(root.spend)
  const used = money(spend?.used)
  const limit = money(spend?.limit)
  if (used && limit && limit.amount > 0) {
    return { used: used.amount, limit: limit.amount, currency: used.currency, limitReached }
  }

  if (extra?.is_enabled === true) {
    const credits = num(extra.used_credits)
    const cap = num(extra.monthly_limit)
    if (credits !== null && cap !== null && cap > 0) {
      const scale = 10 ** (num(extra.decimal_places) ?? 2)
      return { used: credits / scale, limit: cap / scale, currency: currency(extra.currency), limitReached }
    }
  }
  return null
}

function parseBudget(value: unknown): Budget | null {
  const b = rec(value)
  const used = num(b?.used)
  const limit = num(b?.limit)
  if (!b || used === null || limit === null || limit <= 0) return null
  return { used, limit, currency: currency(b.currency), limitReached: b.limitReached === true }
}

// The shared cache file, checked field by field: it outlives plugin versions and may be edited by hand.
export function parseCache(json: unknown): Cache | null {
  const c = rec(json)
  const fetchedAt = num(c?.fetchedAt)
  const attemptedAt = num(c?.attemptedAt)
  if (!c || c.v !== 1 || fetchedAt === null || attemptedAt === null) return null
  const retryAt = num(c.retryAt)
  return {
    v: 1,
    budget: parseBudget(c.budget),
    fetchedAt,
    attemptedAt,
    ...(retryAt !== null ? { retryAt } : {}),
    ...(typeof c.error === "string" ? { error: c.error } : {}),
  }
}

export function isDue(cache: Cache | null, now: number): boolean {
  if (!cache) return true
  return now - cache.attemptedAt >= FETCH_EVERY && now >= (cache.retryAt ?? 0)
}

// After a 429: the Retry-After seconds when longer than the normal interval, never sooner than it,
// and never more than an hour, since the value lands in the cache every window reads.
export function retryAfter(header: string | null, now: number): number {
  const seconds = header === null ? Number.NaN : Number(header)
  const wait = Number.isFinite(seconds) && seconds > 0 ? seconds * 1000 : 0
  return now + Math.min(Math.max(wait, FETCH_EVERY), MAX_RETRY)
}

// The Anthropic entry of opencode's auth.json. An expired token is never used: refreshing it here
// would race the auth plugin over a rotating refresh token, so the panel waits for its next refresh.
export function readToken(auth: unknown, now: number): Token {
  const anthropic = rec(rec(auth)?.anthropic)
  if (anthropic?.type === "api") return { reason: "signed in with an API key, no seat budget" }
  const access = anthropic?.access
  if (anthropic?.type !== "oauth" || typeof access !== "string" || access === "") return { reason: NOT_SIGNED_IN }
  const expires = num(anthropic.expires)
  if (expires !== null && expires <= now) return { reason: "token expired, refreshes on next anthropic request" }
  return { access }
}

function format(amount: number, code: string, digits: number): string {
  try {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: code,
      minimumFractionDigits: digits,
      maximumFractionDigits: digits,
    }).format(amount)
  } catch {
    return code ? `${amount.toFixed(digits)} ${code}` : amount.toFixed(digits)
  }
}

// Level 1 (warning) at 70% spent or on pace for 85%; level 2 (critical) at 90% spent, on pace to
// exceed the cap, or once Anthropic reports the limit reached. The month starts on the 1st, UTC:
// the usage endpoint does not return a reset date, so that boundary is an assumption.
export function summarize(budget: Budget, now: Date): Summary {
  const t = now.getTime()
  const start = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)
  const next = Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)
  const elapsed = (t - start) / DAY
  const left = (next - t) / DAY

  const spent = budget.limit > 0 ? budget.used / budget.limit : 0
  // A month-to-date pace is noise before day 2.
  const projected = elapsed >= 2 ? (budget.used / elapsed) * ((next - start) / DAY) : null
  const paced = projected !== null && budget.limit > 0 ? projected / budget.limit : 0
  const level = budget.limitReached || spent >= 0.9 || paced > 1 ? 2 : spent >= 0.7 || paced >= 0.85 ? 1 : 0

  const p = spent * 100
  const percent = `${p < 10 ? Math.round(p * 10) / 10 : Math.round(p)}%`
  const remaining = left >= 2 ? `${Math.floor(left)}d left` : `${Math.floor(left * 24)}h left`
  const cap = format(budget.limit, budget.currency, Number.isInteger(budget.limit) ? 0 : 2)

  return {
    amount: `${format(budget.used, budget.currency, 2)} / ${cap}`,
    percent,
    pace: projected === null ? remaining : `on pace for ${format(projected, budget.currency, 0)} · ${remaining}`,
    level,
  }
}

export function ago(ms: number): string {
  const minutes = Math.floor(ms / 60_000)
  if (minutes < 1) return "just now"
  if (minutes < 60) return `${minutes}m ago`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h ago`
  return `${Math.floor(hours / 24)}d ago`
}
