# zsec CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `zsec`, an autoloaded zsh function that stores a secret in the macOS keychain and registers it in `.zwork` or `.zprivate` in one step, lists what is registered, and verifies the two halves still agree.

**Architecture:** One autoloaded zsh function at `functions/zsec` with a `case` subcommand dispatch, plus a warning branch added to `functions/zload_secrets`. A keychain item's ACL names the binary allowed to read it, so the rule throughout is: read a value with whatever wrote it. `zsec` writes with `keyring` over stdin and reads back with `keyring`, keeping secrets out of argv and keeping adds silent. `zload_secrets` reads with `security`, which costs one Always-Allow dialog per secret, once. A test file at `tests/zsec.test.zsh` isolates itself with file-path overrides and a throwaway keychain service.

**Tech Stack:** zsh 5.9, `security` (macOS), `keyring` (Homebrew, `/opt/homebrew/bin/keyring`), `shasum`, `pbpaste`.

**Design doc:** `docs/plans/2026-09-16-zsec-cli-design.md`

## Global Constraints

- No secret value may ever appear in argv. Values move by stdin or by variable only.
- No command prints a secret value, in any mode, including errors.
- Nothing is added to the shell startup read path. Startup stays near 1.1s.
- `functions/` files are autoloaded function bodies. No shebang, no top-level `function` keyword, no `#!/...` line. Match the style of `functions/zload_secrets`.
- Every failure exits non-zero with a plain message. No zsh tracebacks, no bare `set -e` abort.
- File-path overrides `ZSEC_WORK_FILE` and `ZSEC_PRIVATE_FILE` default to `$ZDOTDIR/.zwork` and `$ZDOTDIR/.zprivate`. Tests set them. Production never does.
- Tests touch keychain service `zsec-selftest` only, never `system` or any real service.
- No secret value may ever reach the argv of an external command. This is not abstract: this machine runs an EDR agent as a live Endpoint Security extension and `auditd` is running, so argv is captured on every exec and shipped off-host. `printf` and `print` are zsh builtins and are fine.
- Write secrets with `keyring set` over stdin. Never `security add-generic-password -w "$value"`.
- Read a value with whatever binary wrote it, or macOS raises an authorization dialog.
- Repo root for all paths below is `~/.config/zsh`. Git commands run from `~/.config` with the `zsh/` prefix, because the repo root is one level up.
- Never name a local `status`, `path`, `argv`, `options` or `signals`. zsh reserves them; `local status=...` fails with "read-only variable" and aborts the function.
- Conventional commits, one logical change per commit.

## File Structure

| Path | Status | Responsibility |
|---|---|---|
| `functions/zsec` | create | The whole CLI. Dispatch, add, ls, doctor, help. |
| `functions/zload_secrets` | modify | Add the failed-lookup warning. |
| `tests/zsec.test.zsh` | create | Test harness plus all 15 cases. |
| `README.md` | modify | Point the secrets section at `zsec`. |

`zsec` stays in one file on purpose. Splitting the subcommands across autoloaded files would mean four files sharing private helpers with no module system to scope them, which is worse than one 200-line file with clear sections.

---

### Task 1: Test harness plus the first failing test

**Files:**
- Create: `tests/zsec.test.zsh`
- Create: `functions/zsec` (stub only)

**Interfaces:**
- Consumes: nothing.
- Produces: `assert_eq NAME EXPECTED ACTUAL`, `assert_exit_pipe NAME EXPECTED_CODE VALUE CMD...`, `assert_no_leak NAME VALUE TEXT`, `kc_get SERVICE ACCOUNT`, `track ACCOUNT`, `setup_fixtures` which sets `ZSEC_WORK_FILE`/`ZSEC_PRIVATE_FILE` to fresh temp files and echoes nothing, and `TEST_SERVICE=zsec-selftest`. Later tasks add cases to this file and call these helpers.

- [ ] **Step 1: Write the harness and the first failing test**

Create `tests/zsec.test.zsh`:

```zsh
#!/usr/bin/env zsh
# Tests for functions/zsec. Run: zsh tests/zsec.test.zsh
emulate -L zsh
# No err_return here on purpose. Several cases deliberately run commands that
# exit non-zero, and err_return would abort the run instead of asserting.

# fpath points at the REAL functions directory, because that is the code under
# test. ZDOTDIR deliberately does not. It is read only by zsec's default path
# resolution, so aiming it at an empty temp directory means any fallback lands
# there instead of the user's live .zwork and .zprivate.
fpath=("${0:A:h:h}/functions" $fpath)
autoload -Uz zsec zload_secrets

typeset -g TEST_SERVICE=zsec-selftest
typeset -g PASS=0 FAIL=0
typeset -ga TMPFILES=()
typeset -ga TMPDIRS=()
typeset -ga TEST_ACCOUNTS=()

typeset -g ZDOTDIR
ZDOTDIR=$(mktemp -d) || { print -ru2 -- "harness: mktemp -d failed"; exit 1 }
TMPDIRS+=("$ZDOTDIR")

# All three arrays must be declared BEFORE the trap is installed, or an early
# abort runs cleanup against undefined names.
cleanup() {
  local a
  for a in $TEST_ACCOUNTS; do
    security delete-generic-password -s "$TEST_SERVICE" -a "$a" >/dev/null 2>&1 || true
  done
  # zsec writes <file>.bak-<timestamp> beside every manifest it edits. Those
  # names are not in TMPFILES, so without this line each run leaks one backup
  # per add into $TMPDIR, forever. They hold manifest scaffolding, never values.
  (( $#TMPFILES )) && rm -f ${^TMPFILES}.bak-*(N)
  (( $#TMPFILES )) && rm -f $TMPFILES
  (( $#TMPDIRS ))  && rm -rf $TMPDIRS
  return 0
}
# Every signal handler must exit explicitly. A plain `trap cleanup INT` runs
# cleanup and then RESUMES the script, so Ctrl-C would wipe the fixtures and let
# the remaining cases run against deleted files, reporting meaningless failures.
# QUIT is the worst case: installing a non-exiting handler overrides the default
# terminate action, making SIGQUIT less safe than having no handler at all.
# cleanup must stay idempotent, because `exit` from a handler re-fires EXIT.
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 131' QUIT
trap 'cleanup; exit 143' TERM

# Register an account name so cleanup removes it even if a test aborts, AND
# delete any stale item of that name up front. The delete is what stops a
# leftover from a previous run pre-empting a case: `zsec add` without -f refuses
# early when the item already exists, roughly sixty lines before the manifest
# logic, so a stale item makes a case pass green without ever reaching the guard
# it exists to pin. track() runs before every add, so one line covers them all.
track() {
  security delete-generic-password -s "$TEST_SERVICE" -a "$1" >/dev/null 2>&1
  TEST_ACCOUNTS+=("$1")
}

# Read a keychain value with stderr suppressed. `security` writes
# "The specified item could not be found" to the terminal on a miss, which
# would pollute the output of any case that asserts an item is absent.
# Read a value the way zsec wrote it. zsec writes with keyring, so keyring reads
# it back silently; `security -w` on the same item would raise a dialog.
kc_get() { keyring get "$1" "$2" 2>/dev/null }

# Plant a fixture item that `security` must be able to READ, which is only
# doctor's `security -g` hex check. Planting with `security` keeps that read
# silent. Safe here and nowhere else: this form puts the value in argv, which is
# fine for the fake values tests use and forbidden for a real secret.
kc_plant() { security add-generic-password -U -s "$1" -a "$2" -w "$3" 2>/dev/null }

setup_fixtures() {
  local w p
  # Unchecked mktemp is the one path back to catastrophe: on failure w is empty,
  # `export ZSEC_WORK_FILE=""` runs, and zsec's ${ZSEC_WORK_FILE:-...} fallback
  # treats empty as unset, sending the write at the real manifest.
  w=$(mktemp) || { print -ru2 -- "harness: mktemp failed"; exit 1 }
  p=$(mktemp) || { print -ru2 -- "harness: mktemp failed"; exit 1 }
  TMPFILES+=("$w" "$p")
  print -r -- "zload_secrets <<'SECRETS'" >  "$w"
  print -r -- "SECRETS"                   >> "$w"
  print -r -- "zload_secrets <<'SECRETS'" >  "$p"
  print -r -- "SECRETS"                   >> "$p"
  export ZSEC_WORK_FILE="$w" ZSEC_PRIVATE_FILE="$p"
}

assert_eq() {
  local name="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then
    (( PASS++ )); print -r -- "  ok   $name"
  else
    (( FAIL++ )); print -r -- "  FAIL $name"
    print -r -- "       want: [$want]"
    print -r -- "       got:  [$got]"
  fi
}

# Assert a command exits with an expected code, feeding VALUE on its stdin.
# The pipe form is the one the cases need, because `zsec add` reads its value
# from stdin and a plain argv-only helper cannot express that.
assert_exit_pipe() {
  local name="$1" want="$2" value="$3"; shift 3
  local got=0
  printf '%s' "$value" | "$@" >/dev/null 2>&1 || got=$?
  assert_eq "$name" "$want" "$got"
}

# Assert a secret value does not appear in captured output. This is the only
# check on the "no command prints a secret value" constraint, so every case that
# feeds a real value through zsec should call it. grep -F because a value is
# arbitrary bytes, not a regex.
assert_no_leak() {
  local name="$1" value="$2" text="$3"
  assert_eq "$name" "0" "$(print -r -- "$text" | grep -cF -- "$value")"
}

# Establish safe defaults BEFORE any case runs. Each test calls setup_fixtures
# again to get its own pair of files, but this top-level call means a test that
# forgets that call writes into a stale temp file rather than the user's real .zwork.
# Without it, a forgotten call sends `zsec add` at the live manifest and the
# real `system` keychain, and cleanup cannot undo either.
setup_fixtures

# ---------------------------------------------------------------- case 1
test_add_creates_both_halves() {
  setup_fixtures; track ONE_TOKEN
  # Capture both streams rather than discarding them. Discarding was the old
  # shape, and it left the no-leak constraint with zero coverage anywhere.
  local out
  out=$(printf 'hunter2' | zsec add ONE_TOKEN --service "$TEST_SERVICE" 2>&1)
  assert_eq "1a keychain item created" \
    "hunter2" "$(kc_get "$TEST_SERVICE" ONE_TOKEN)"
  assert_eq "1b manifest line appended" \
    "sec|ONE_TOKEN|$TEST_SERVICE" \
    "$(grep '^sec|ONE_TOKEN' "$ZSEC_WORK_FILE")"
  assert_no_leak "1c value never echoed" "hunter2" "$out"
}

print -r -- "zsec tests"
test_add_creates_both_halves

print -r -- ""
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
```

Create `functions/zsec` as a stub so `autoload` resolves:

```zsh
emulate -L zsh
print -ru2 -- "zsec: not implemented"
return 1
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: FAIL on `1a keychain item created` and `1b manifest line appended`, PASS on `1c value never echoed` (the stub prints nothing containing the value), final line `1 passed, 2 failed`, exit 1.

- [ ] **Step 3: Commit the harness**

```bash
git -C ~/.config add zsh/tests/zsec.test.zsh zsh/functions/zsec
git -C ~/.config commit -m "test(zsh): add zsec test harness and first failing case"
```

---

### Task 2: `zsec add` happy path

**Files:**
- Modify: `functions/zsec`
- Test: `tests/zsec.test.zsh` (case 1 already written in Task 1)

**Interfaces:**
- Consumes: `assert_eq`, `setup_fixtures`, `track`, `TEST_SERVICE` from Task 1.
- Produces: `_zsec_die MSG...`, which prints `zsec: MSG` lines to stderr and returns 1, and `_zsec_spec_line VAR SVC ACCT`, which echoes the manifest line. Both are reused by later tasks.
- Deliberately NOT produced: target-file selection and value reading stay inlined in `_zsec_add`. An earlier draft of this plan declared `_zsec_manifest_file` and `_zsec_read_value` as helpers, but no later task calls either, and extracting a helper with one caller is abstraction ahead of need.

- [ ] **Step 1: Replace the stub with the add path**

Overwrite `functions/zsec`:

```zsh
emulate -L zsh
setopt local_options extended_glob no_multios no_xtrace no_verbose
# CLI over the two-part secrets model: value in the macOS keychain, name in a
# zload_secrets manifest line. See docs/plans/2026-09-16-zsec-cli-design.md.
#
# extended_glob above is REQUIRED. `emulate -L zsh` turns it off, and without it
# the [A-Za-z_][A-Za-z0-9_]# name check below matches nothing, so every valid
# variable name gets rejected. Verified on zsh 5.9.
# no_xtrace is required too. `emulate -L zsh` does NOT reset xtrace, so under
# `zsh -x` every secret value appears in the trace. Verified. It is scoped by
# local_options, so tracing resumes normally once zsec returns.
# no_multios is also required. With MULTIOS on (the zsh default), the
# `cmd 2>&1 >/dev/null | grep` idiom in the doctor hex check TEES stdout into
# the pipe instead of discarding it, so the grep sees the whole attribute dump.
# The option has to be set where the redirection is WRITTEN, which is here.
#
# Secrets are written with `keyring set` over stdin and read back with
# `keyring get`. Two rules are in tension here and both are load-bearing.
#
# 1. Never put a secret in argv. `security add-generic-password -w "$v"` would.
#    This machine runs an EDR agent registered as an Endpoint Security
#    extension, and auditd is running, so argv is captured on every exec and
#    shipped off-host with months of retention. That is a disclosure, not a
#    theoretical race. `security ... -w` cannot read from stdin (tested: it
#    ignores the pipe, and over a pty it stores an empty value), so writing with
#    `security` at all means leaking to telemetry.
# 2. Read with whatever wrote it. A keychain item's ACL names the binary allowed
#    to read its data, so reading a keyring-written item with `security` raises
#    a GUI dialog. That is why the readback below uses `keyring get` and not
#    `security -w`, even though `security -w` is what zload_secrets will use.
#
# The residual cost is one dialog per secret, the first time zload_secrets reads
# it. Always Allow makes that permanent. This was reverted once already; if you
# are about to "simplify" it to a single binary, re-read rule 1.

_zsec_die() {
  local first=1 line
  for line in "$@"; do
    if (( first )); then print -ru2 -- "zsec: $line"; first=0
    else                 print -ru2 -- "      $line"; fi
  done
  return 1
}

_zsec_spec_line() {
  local var="$1" svc="$2" acct="$3"
  if [[ "$svc" == system && "$acct" == "$var" ]]; then print -r -- "sec|$var"
  elif [[ "$acct" == "$var" ]];                   then print -r -- "sec|$var|$svc"
  else                                                 print -r -- "sec|$var|$svc|$acct"; fi
}

_zsec_add() {
  local var="" svc=system acct="" clip=0 personal=0 force=0
  while (( $# )); do
    case "$1" in
      -c|--clipboard) clip=1 ;;
      -p|--personal)  personal=1 ;;
      -f|--force)     force=1 ;;
      # Arity must be checked. Without it, a trailing `--service` consumes
      # nothing, the later `shift` fails with a raw zsh builtin error, and the
      # loop carries on with an empty service, writing `sec|VAR|` to the file.
      --service)      [[ -n "${2-}" ]] || { _zsec_die "--service needs a value."; return 1 }
                      svc="$2"; shift ;;
      --account)      [[ -n "${2-}" ]] || { _zsec_die "--account needs a value."; return 1 }
                      acct="$2"; shift ;;
      --value|--value=*)
        _zsec_die "--value is not supported on purpose." \
                  "A value passed as an argument is visible to any process via \`ps\`." \
                  "Use -c for the clipboard, or pipe the value in on stdin."
        return 1 ;;
      -h|--help)      _zsec_help_add; return 0 ;;
      -*)             _zsec_die "unknown option '$1'. Try: zsec add -h"; return 1 ;;
      *)              if [[ -z "$var" ]]; then var="$1"
                      else _zsec_die "unexpected argument '$1'. Try: zsec add -h"; return 1; fi ;;
    esac
    shift
  done

  [[ -n "$var" ]] || { _zsec_die "add needs a variable name. Try: zsec add -h"; return 1; }
  [[ "$var" == [A-Za-z_][A-Za-z0-9_]# ]] || {
    _zsec_die "'$var' is not a valid shell variable name." \
              "Use letters, digits and underscores, and do not start with a digit."
    return 1; }
  : ${acct:=$var}

  # Service and account end up in the manifest line, so they get the same byte
  # gate as the value, plus a ban on the field separator. A '|' would silently
  # shift every later field, and a control character would be written literally.
  local _f
  for _f in "$svc" "$acct"; do
    [[ "$_f" == *[^\ -~]* || "$_f" == *'|'* ]] && {
      _zsec_die "service and account must be printable ASCII and contain no '|'." \
                "'|' is the manifest field separator, so it would corrupt the line."
      return 1; }
  done

  local file
  if (( personal )); then file="${ZSEC_PRIVATE_FILE:-$ZDOTDIR/.zprivate}"
  else                    file="${ZSEC_WORK_FILE:-$ZDOTDIR/.zwork}"; fi

  # doctor treats a name declared in BOTH manifests as a defect: it reports
  # DUPLICATE, exits 1, and whichever file loads second silently wins. add must
  # not create that state. Checked before anything is written.
  local other
  if (( personal )); then other="${ZSEC_WORK_FILE:-$ZDOTDIR/.zwork}"
  else                    other="${ZSEC_PRIVATE_FILE:-$ZDOTDIR/.zprivate}"; fi
  if grep -qE "^sec\|$var(\||$)" "$other" 2>/dev/null; then
    _zsec_die "$var is already declared in ${other:t}." \
              "Two manifests naming one variable is the DUPLICATE state doctor" \
              "reports, and the file that loads second wins. Remove that line first."
    return 1
  fi

  local value
  if (( clip )); then
    value=$(pbpaste)
  elif [[ ! -t 0 ]]; then
    value=$(cat); value="${value%$'\n'}"
  else
    local v1 v2
    read -rs "v1?Value for $var: "; print -u2
    read -rs "v2?Repeat:          "; print -u2
    [[ "$v1" == "$v2" ]] || { _zsec_die "the two entries did not match. Nothing was written."; return 1; }
    value="$v1"
  fi

  [[ -n "$value" ]] || {
    _zsec_die "refusing to store an empty value for $var." \
              "$( (( clip )) && print -n 'The clipboard is empty. Copy the secret first, then re-run.' \
                             || print -n 'No value was given.' )"
    return 1; }

  if [[ "$value" == *[^\ -~]* ]]; then
    _zsec_die "refusing to store $var, the value is not printable ASCII." \
              "It contains a newline, tab, accent or emoji. macOS hands those back" \
              "hex-encoded, so the startup loader would export the hex string instead" \
              "of your secret, with no warning. Nothing was written."
    return 1
  fi

  local existed=0
  security find-generic-password -s "$svc" -a "$acct" >/dev/null 2>&1 && existed=1
  if (( existed && ! force )); then
    _zsec_die "$var already exists in the keychain (service: $svc)." \
              "Pass -f to overwrite it, or pick a different name."
    return 1
  fi

  # Delete before creating, always. Two reasons, both measured:
  #  1. `keyring set` CANNOT update an item it does not own. Run against one of
  #     the legacy secrets that `security` created, it throws a Python traceback
  #     and fails, so -f could never rotate them. Rotation is a core use case.
  #  2. Creating fresh makes the item keyring-owned, so the readback below and
  #     every later zsec read stay silent instead of raising a dialog.
  # On the non-force path the item does not exist, so the delete is a no-op.
  security delete-generic-password -s "$svc" -a "$acct" >/dev/null 2>&1
  printf '%s' "$value" | keyring set "$svc" "$acct" 2>/dev/null || {
    if (( existed )); then
      _zsec_die "could not store $var in the keychain (service: $svc)." \
                "The previous value was deleted before this failed, so it is GONE." \
                "Re-run with the value you still have in hand."
    else
      _zsec_die "could not store $var in the keychain (service: $svc)."
    fi
    return 1; }

  local want got
  want=$(printf '%s' "$value" | shasum -a 256)
  # Read back with the SAME binary that wrote, or this dialogs on every add.
  # The $(...) strips a trailing newline if the reader adds one, and strips
  # nothing else, so a value with trailing SPACES still round-trips. printf is a
  # builtin, so neither side puts the value in a real process's argv.
  got=$(printf '%s' "$(keyring get "$svc" "$acct" 2>/dev/null)" | shasum -a 256)
  [[ "$want" == "$got" ]] || {
    _zsec_die "verification failed for $var." \
              "The value was stored but does not read back correctly, so an assumption" \
              "in zsec is wrong. The keychain item was left as it is and the manifest" \
              "was NOT updated. Please report this."
    return 1; }

  local line; line=$(_zsec_spec_line "$var" "$svc" "$acct")
  # Compare the whole line, not just the name. Matching on the name alone meant
  # that rotating a secret to a different service wrote the new keychain item,
  # left the manifest pointing at the OLD service, printed "already registered,
  # left alone", exited 0, and left doctor reporting ok while the shell kept
  # exporting the old value. That is the exact drift this tool exists to stop.
  # grep -E, not plain grep. BSD BRE alternation is not portable here, and the
  # (\||$) anchor is what stops sec|FOO from matching a line for sec|FOO_BAR.
  local existing action
  existing=$(grep -E "^sec\|$var(\||$)" "$file" 2>/dev/null | head -1)
  if [[ "$existing" == "$line" ]]; then
    action="already registered in ${file:t}, unchanged"
  else
    # Only the INSERT path needs a heredoc block to aim at. A rewrite replaces
    # a line that is already there, wherever it sits.
    [[ -n "$existing" ]] || grep -q '^zload_secrets <<' "$file" 2>/dev/null || {
      _zsec_die "$file has no 'zload_secrets <<' block, so there is nowhere to add the line." \
                "The keychain item WAS written. Add this line yourself:" \
                "    $line"
      return 1; }
    # Timestamps are second-granularity, so two adds in the same second would
    # overwrite one backup. Bump a suffix until the name is free.
    local bak="$file.bak-$(date +%Y%m%dT%H%M%S)" n=1
    while [[ -e "$bak" ]]; do bak="$file.bak-$(date +%Y%m%dT%H%M%S)-$n"; (( n++ )); done
    cp -p "$file" "$bak" || {
      _zsec_die "could not back up $file, so refusing to modify it." \
                "The keychain item WAS written. Add this line yourself:" "    $line"
      return 1; }
    local tmp awkrc=0; tmp=$(mktemp) || {
      _zsec_die "mktemp failed. The keychain item WAS written." \
                "Add this line yourself:" "    $line"
      return 1; }
    # ENVIRON, not `awk -v`. The -v form processes backslash escapes, so a
    # service containing a literal \t would be written as a real tab.
    if [[ -n "$existing" ]]; then
      ZSEC_OLD="$existing" ZSEC_NEW="$line" awk \
        '$0 == ENVIRON["ZSEC_OLD"] && !d { print ENVIRON["ZSEC_NEW"]; d=1; next } { print }' \
        "$file" > "$tmp" || awkrc=$?
      action="rewrote the line in ${file:t}
    was: $existing
    now: $line"
    else
      ZSEC_INS="$line" awk '/^SECRETS$/ && !ins { print ENVIRON["ZSEC_INS"]; ins=1 } { print }' \
        "$file" > "$tmp" || awkrc=$?
      action="registered in ${file:t} as: $line"
    fi
    # awk's status must gate the mv. Without it a failing awk leaves a truncated
    # $tmp that then clobbers the manifest.
    if (( awkrc != 0 )) || ! mv "$tmp" "$file"; then
      rm -f "$tmp"
      _zsec_die "failed to update $file. The keychain item WAS written." \
                "Add this line yourself:" "    $line"
      return 1
    fi
    # awk exits 0 even when it matched nothing, so a block terminated with
    # anything other than SECRETS, or never terminated, would copy the file
    # through unchanged and report success. Confirm the line actually landed.
    # Presence of the new line is not enough. The rewrite replaces only the
    # FIRST match (awk's !d), so a second stale line for the same name would
    # survive and race it at startup. Assert the count, which is the invariant
    # test 18c states but the code did not enforce.
    local cnt; cnt=$(grep -cE "^sec\|$var(\||$)" "$file" 2>/dev/null)
    if (( cnt != 1 )); then
      _zsec_die "$file now has $cnt lines for $var, expected exactly 1." \
                "The keychain item WAS written. A backup is at $bak." \
                "Fix the manifest by hand so only this line remains:" "    $line"
      return 1
    fi
    grep -qxF -- "$line" "$file" || {
      if [[ -n "$existing" ]]; then
        _zsec_die "could not rewrite the manifest line in $file." \
                  "The keychain item WAS written. A backup is at $bak." \
                  "Replace this line yourself:" \
                  "    was: $existing" "    now: $line"
      else
        _zsec_die "could not place the manifest line in $file." \
                  "The 'zload_secrets <<' block has no SECRETS terminator, so there" \
                  "is nowhere to insert it. The keychain item WAS written." \
                  "Add this line yourself:" "    $line"
      fi
      return 1; }
  fi

  print -r -- "$( (( existed )) && print -n updated || print -n created ) $var in the keychain (service: $svc)"
  print -r -- "$action"
  print -r -- "not in this shell yet. open a new shell, or: source $file"
}

_zsec_help_add() { print -r -- "zsec add: not implemented yet" }

case "${1:-}" in
  add) shift; _zsec_add "$@" ;;
  *)   _zsec_die "unknown subcommand '${1:-}'"; return 1 ;;
esac
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: `ok   1a keychain item created`, `ok   1b manifest line appended`, final line `3 passed, 0 failed`, exit 0.

- [ ] **Step 3: Commit**

```bash
git -C ~/.config add zsh/functions/zsec
git -C ~/.config commit -m "feat(zsh): add zsec add, writes keychain and manifest together"
```

---

### Task 3: Idempotency, force, and the refuse-on-existing rule

**Files:**
- Modify: `tests/zsec.test.zsh`

**Interfaces:**
- Consumes: `_zsec_add` from Task 2. No source changes expected; this task proves Task 2's behavior and fixes it only if a case fails.
- Produces: nothing new.

- [ ] **Step 1: Write the failing tests**

Add before the `print -r -- ""` summary block in `tests/zsec.test.zsh`, and add the three calls next to the existing `test_add_creates_both_halves` call:

```zsh
# ---------------------------------------------------------------- case 2,3,4
test_add_is_idempotent() {
  setup_fixtures; track TWO_TOKEN
  # Seed a prefix-collision line. Production checks registration with
  # `grep -qE "^sec\|$var(\||$)"`, and that (\||$) anchor is the only thing
  # stopping sec|TWO_TOKEN from matching this line. Without the seed, nothing in
  # the suite would notice if the anchor were dropped.
  print -r -- "sec|TWO_TOKEN_X|other" >> "$ZSEC_WORK_FILE"
  printf 'v1' | zsec add TWO_TOKEN --service "$TEST_SERVICE" >/dev/null 2>&1
  assert_eq "2a inserted despite a prefix-collision line" \
    "1" "$(grep -cE '^sec\|TWO_TOKEN\|' "$ZSEC_WORK_FILE")"
  printf 'v1' | zsec add TWO_TOKEN --service "$TEST_SERVICE" -f >/dev/null 2>&1
  assert_eq "2b no duplicate manifest line" \
    "1" "$(grep -cE '^sec\|TWO_TOKEN\|' "$ZSEC_WORK_FILE")"
}

test_add_refuses_existing_without_force() {
  setup_fixtures; track THREE_TOKEN
  printf 'original' | zsec add THREE_TOKEN --service "$TEST_SERVICE" >/dev/null 2>&1
  assert_exit_pipe "3a exits 1 without -f" 1 'replacement' \
    zsec add THREE_TOKEN --service "$TEST_SERVICE"
  assert_eq "3b value untouched" \
    "original" "$(kc_get "$TEST_SERVICE" THREE_TOKEN)"
}

test_add_force_overwrites() {
  setup_fixtures; track FOUR_TOKEN
  printf 'original'    | zsec add FOUR_TOKEN --service "$TEST_SERVICE"    >/dev/null 2>&1
  # Without this, a first add that silently did nothing would let the second one
  # create the item fresh and the case would pass while proving only "create".
  assert_eq "4a original stored first" \
    "original" "$(kc_get "$TEST_SERVICE" FOUR_TOKEN)"
  printf 'replacement' | zsec add FOUR_TOKEN --service "$TEST_SERVICE" -f >/dev/null 2>&1
  assert_eq "4b -f overwrites" \
    "replacement" "$(kc_get "$TEST_SERVICE" FOUR_TOKEN)"
}

# ---------------------------------------------------------------- case 16
# Pinned deliberately. The bug this guards was the worst the function ever had:
# awk exits 0 when it matches nothing, so a block terminated with anything other
# than SECRETS got copied through untouched while zsec printed "registered in
# ...". A silent false success plus an orphaned keychain item. Fixture only, and
# the keychain item is real, so track it.
test_add_refuses_unplaceable_manifest_line() {
  setup_fixtures; track SIXTEEN_TOKEN
  print -r -- "zload_secrets <<'EOF'" >  "$ZSEC_WORK_FILE"
  print -r -- "EOF"                   >> "$ZSEC_WORK_FILE"
  local before; before=$(md5 -q "$ZSEC_WORK_FILE")
  assert_exit_pipe "16a exits 1 when the line cannot be placed" 1 'v' \
    zsec add SIXTEEN_TOKEN --service "$TEST_SERVICE"
  assert_eq "16b manifest left untouched" "$before" "$(md5 -q "$ZSEC_WORK_FILE")"
  # The error message promises "The keychain item WAS written". Pin that, or the
  # promise is untested and could silently become a lie.
  assert_eq "16c keychain item was still written" "v" "$(kc_get "$TEST_SERVICE" SIXTEEN_TOKEN)"
}
```

- [ ] **Step 2: Run to see the result**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: all nine new assertions pass, giving `12 passed, 0 failed`. If any fail, fix `functions/zsec` before committing. The likely failure is `2 no duplicate manifest line`, if the registration grep does not match a bare `sec|VAR` line. Verify that pattern directly, checking all three cases:

```bash
printf 'sec|TWO_TOKEN\n'     | grep -cE '^sec\|TWO_TOKEN(\||$)'   # want 1
printf 'sec|TWO_TOKEN|svc\n' | grep -cE '^sec\|TWO_TOKEN(\||$)'   # want 1
printf 'sec|TWO_TOKEN_X\n'   | grep -cE '^sec\|TWO_TOKEN(\||$)'   # want 0
```

- [ ] **Step 3: Commit**

```bash
git -C ~/.config add zsh/tests/zsec.test.zsh zsh/functions/zsec
git -C ~/.config commit -m "test(zsh): cover zsec add idempotency and force"
```

---

### Task 4: Manifest line forms and value handling

**Files:**
- Modify: `tests/zsec.test.zsh`

**Interfaces:**
- Consumes: `_zsec_spec_line` behavior from Task 2.
- Produces: nothing new.

- [ ] **Step 1: Write the failing tests**

Add to `tests/zsec.test.zsh` and call them:

```zsh
# ---------------------------------------------------------------- case 5,6
test_line_form_service_only() {
  setup_fixtures; track FIVE_TOKEN
  printf 'v' | zsec add FIVE_TOKEN --service "$TEST_SERVICE" >/dev/null
  assert_eq "5 sec|VAR|SVC form" \
    "sec|FIVE_TOKEN|$TEST_SERVICE" "$(grep '^sec|FIVE_TOKEN' "$ZSEC_WORK_FILE")"
}

test_line_form_service_and_account() {
  setup_fixtures; track someacct
  printf 'v' | zsec add SIX_TOKEN --service "$TEST_SERVICE" --account someacct >/dev/null
  assert_eq "6 sec|VAR|SVC|ACCT form" \
    "sec|SIX_TOKEN|$TEST_SERVICE|someacct" "$(grep '^sec|SIX_TOKEN' "$ZSEC_WORK_FILE")"
}

# ---------------------------------------------------------------- case 7,8,9,10
test_rejects_empty_value() {
  setup_fixtures
  assert_exit_pipe "7a exits 1 on empty" 1 '' \
    zsec add SEVEN_TOKEN --service "$TEST_SERVICE"
  assert_eq "7b nothing registered"  ""  "$(grep '^sec|SEVEN_TOKEN' "$ZSEC_WORK_FILE")"
}

test_rejects_interior_newline() {
  setup_fixtures; track EIGHT_TOKEN
  assert_exit_pipe "8a exits 1 on newline" 1 $'line1\nline2' \
    zsec add EIGHT_TOKEN --service "$TEST_SERVICE"
  assert_eq "8b no keychain item" "" "$(kc_get "$TEST_SERVICE" EIGHT_TOKEN)"
  assert_eq "8c nothing registered"   ""  "$(grep '^sec|EIGHT_TOKEN' "$ZSEC_WORK_FILE")"
}

test_rejects_accented() {
  setup_fixtures; track NINE_TOKEN
  assert_exit_pipe "9a exits 1 on accent" 1 $'caf\xc3\xa9' \
    zsec add NINE_TOKEN --service "$TEST_SERVICE"
  assert_eq "9b nothing registered" ""  "$(grep '^sec|NINE_TOKEN' "$ZSEC_WORK_FILE")"
  # Redundant today and kept on purpose. It was written when the readback used
  # `security -w`, which returns hex for an accented value, so disabling the gate
  # left 9a and 9b green and an orphaned item was the only evidence. The readback
  # is keyring now and round-trips losslessly, so 9a/9b catch it directly. This
  # re-arms automatically if the readback ever moves back to `security`.
  assert_eq "9c no keychain item" "" "$(kc_get "$TEST_SERVICE" NINE_TOKEN)"
}

test_preserves_surrounding_spaces() {
  setup_fixtures; track TEN_TOKEN
  local out
  out=$(printf '  padded  ' | zsec add TEN_TOKEN --service "$TEST_SERVICE" 2>&1)
  assert_eq "10a spaces survive byte for byte" \
    "  padded  " "$(kc_get "$TEST_SERVICE" TEN_TOKEN)"
  assert_no_leak "10b value never echoed" "  padded  " "$out"
}

# ---------------------------------------------------------------- case 17
# Pins the rotation path, which was broken and briefly shipped green. `keyring
# set` cannot UPDATE an item it does not own: against a security-created item it
# throws a Python traceback and fails, so -f could not rotate ANY pre-existing
# secret. zsec now deletes before creating. Plant with security here precisely
# to reproduce the foreign-owner case.
# ---------------------------------------------------------------- case 18 (C1)
# The worst defect the whole-branch review found, and it shipped green through
# six task reviews. Rotating to a DIFFERENT service wrote the new keychain item,
# left the manifest naming the OLD service, printed "already registered, left
# alone", exited 0, and doctor said ok while the shell kept exporting the old
# value. Rotation is exactly when you cannot afford that: you rotate because the
# old credential was revoked or leaked.
test_rotate_to_new_service_rewrites_the_line() {
  setup_fixtures; track EIGHTEEN_TOKEN
  printf 'oldv' | zsec add EIGHTEEN_TOKEN --service "$TEST_SERVICE" >/dev/null 2>&1
  assert_eq "18a first add registers the old service" \
    "sec|EIGHTEEN_TOKEN|$TEST_SERVICE" "$(grep '^sec|EIGHTEEN_TOKEN' "$ZSEC_WORK_FILE")"
  printf 'newv' | zsec add EIGHTEEN_TOKEN --service "$TEST_SERVICE" --account other -f >/dev/null 2>&1
  assert_eq "18b manifest rewritten, not left stale" \
    "sec|EIGHTEEN_TOKEN|$TEST_SERVICE|other" "$(grep '^sec|EIGHTEEN_TOKEN' "$ZSEC_WORK_FILE")"
  assert_eq "18c exactly one line for the name" \
    "1" "$(grep -cE '^sec\|EIGHTEEN_TOKEN(\||$)' "$ZSEC_WORK_FILE")"
  security delete-generic-password -s "$TEST_SERVICE" -a other >/dev/null 2>&1
}

# ---------------------------------------------------------------- case 19 (C2)
# An invalid identifier made `source` abort inside zload_secrets, silently
# dropping every secret written after it, in a different order each shell start.
test_zload_secrets_skips_an_invalid_name() {
  setup_fixtures; track NINETEEN_TOKEN; track BAD-NAME
  kc_plant "$TEST_SERVICE" NINETEEN_TOKEN 'survivor'
  # Plant the bad name too, so ITS lookup succeeds. Without this the loader
  # routes BAD-NAME to the missing list, never writes `export BAD-NAME=`, and
  # 19b is a tautology that passes with the validation removed. With it planted
  # the cascade is genuinely reachable. Note 19b then catches a regression only
  # probabilistically, since the jobs append in completion order and the abort
  # point moves; 19a is the deterministic pin.
  kc_plant "$TEST_SERVICE" BAD-NAME 'poison'
  local err
  err=$(zload_secrets 2>&1 >/dev/null <<SPEC
sec|BAD-NAME|$TEST_SERVICE
sec|NINETEEN_TOKEN|$TEST_SERVICE
SPEC
)
  assert_eq "19a warns about the invalid name" \
    "1" "$(print -r -- "$err" | grep -c 'invalid variable name')"
  assert_eq "19b the good secret after it still loads" "survivor" "${NINETEEN_TOKEN:-}"
  unset NINETEEN_TOKEN
}

# ---------------------------------------------------------------- case 20 (C2)
test_doctor_flags_a_malformed_name() {
  setup_fixtures
  print -r -- "sec|BAD-NAME|$TEST_SERVICE" >> "$ZSEC_WORK_FILE"
  local out code=0; out=$(zsec doctor 2>&1) || code=$?
  assert_eq "20a exits 1 on a malformed name" "1" "$code"
  assert_eq "20b says MALFORMED" "1" "$(print -r -- "$out" | grep -c '^  MALFORMED .*BAD-NAME')"
}

# ---------------------------------------------------------------- case 21 (C3)
# `emulate -L zsh` does NOT reset xtrace, so `zsh -xl` printed every secret
# value four times. 88 plaintext credential lines for 22 secrets.
test_zsec_add_xtrace_does_not_leak() {
  setup_fixtures; track TWENTYTWO_TOKEN
  # Case 21 covers zload_secrets. zsec's own no_xtrace had no test, so removing
  # it from the setopt line would have gone unnoticed.
  local tr
  tr=$(setopt xtrace; printf 'zsecxsecret' | zsec add TWENTYTWO_TOKEN --service "$TEST_SERVICE" 2>&1)
  assert_no_leak "22 zsec add never leaks the value under xtrace" "zsecxsecret" "$tr"
}

test_xtrace_does_not_leak_values() {
  setup_fixtures; track TWENTYONE_TOKEN
  kc_plant "$TEST_SERVICE" TWENTYONE_TOKEN 'xtracesecret'
  local tr
  tr=$(setopt xtrace; zload_secrets 2>&1 >/dev/null <<SPEC
sec|TWENTYONE_TOKEN|$TEST_SERVICE
SPEC
  )
  assert_no_leak "21 xtrace never prints the value" "xtracesecret" "$tr"
  unset TWENTYONE_TOKEN
}

test_force_rotates_a_foreign_item() {
  setup_fixtures; track SEVENTEEN_TOKEN
  # ORDER MATTERS. A successful `keyring get` on the planted item grants the
  # Python binary ACL access, after which `keyring set` succeeds and the bug
  # becomes unreproducible. Do not read this item before the add below.
  kc_plant "$TEST_SERVICE" SEVENTEEN_TOKEN oldvalue
  assert_exit_pipe "17a -f succeeds over a foreign-owned item" 0 'newvalue' \
    zsec add SEVENTEEN_TOKEN --service "$TEST_SERVICE" -f
  assert_eq "17b value rotated" "newvalue" "$(kc_get "$TEST_SERVICE" SEVENTEEN_TOKEN)"
}
```

- [ ] **Step 2: Run**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: `26 passed, 0 failed`.

Note on case 10: `$(...)` strips trailing newlines but not trailing spaces, so the comparison is valid. If it fails, the bug is real, not an artifact.

- [ ] **Step 3: Commit**

```bash
git -C ~/.config add zsh/tests/zsec.test.zsh zsh/functions/zsec
git -C ~/.config commit -m "test(zsh): cover zsec line forms and value validation"
```

---

### Task 5: `zsec ls`

**Files:**
- Modify: `functions/zsec`
- Modify: `tests/zsec.test.zsh`

**Interfaces:**
- Consumes: `_zsec_die` from Task 2.
- Produces: `_zsec_each_entry FILE CALLBACK LABEL`, which parses one manifest file and calls `CALLBACK VAR SVC ACCT LINENO LABEL` per `sec|` line, expanding `$USER`. `LABEL` is the basename used for display. Task 6 reuses both.

- [ ] **Step 1: Write the failing test**

Add to `tests/zsec.test.zsh` and call it:

```zsh
# ---------------------------------------------------------------- case 11
test_ls_lists_without_values() {
  setup_fixtures; track ELEVEN_TOKEN
  printf 'topsecret' | zsec add ELEVEN_TOKEN --service "$TEST_SERVICE" >/dev/null
  # 2>&1, because the no-print guarantee is supposed to hold "in any mode,
  # including errors", and stdout-only capture cannot see a stderr leak.
  local out; out=$(zsec ls 2>&1)
  assert_eq "11a lists the name" "1" "$(print -r -- "$out" | grep -c ELEVEN_TOKEN)"
  assert_no_leak "11b never prints the value" "topsecret" "$out"
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: FAIL on `11a lists the name`, because `ls` hits the unknown-subcommand branch.

- [ ] **Step 3: Implement `ls`**

Add to `functions/zsec` above the final `case`:

```zsh
# Shared iterator. doctor reuses it, so it is hardened for a second consumer.
# Three things here are load-bearing and each was a verified bug first:
#  1. `|| [[ -n "$_ze_line" ]]` - a bare `read` returns non-zero on a final line
#     with no trailing newline, silently dropping that entry. A registered
#     secret would vanish from ls and doctor with no error at all.
#  2. fd 3, not stdin - the callback inherits fd 0, so a callback that reads
#     stdin eats manifest lines. Measured: a one-`read` callback consumed every
#     second entry.
#  3. `_ze_` prefixes - zsh scopes dynamically, so the callback can see and
#     clobber these. A callback assigning a bare `n` corrupted the line counter.
# `$_ze_n` is the FILE line number, not the ordinal of sec| lines, because
# doctor points the user at a line in a file.
_zsec_each_entry() {
  local _ze_file="$1" _ze_cb="$2" _ze_label="$3" _ze_n=0
  local _ze_line _ze_kind _ze_var _ze_svc _ze_acct
  [[ -r "$_ze_file" ]] || return 0
  # Mirror what zload_secrets will actually see. A QUOTED heredoc (<<'SECRETS')
  # passes $USER through literally and zload_secrets does not expand it, so
  # substituting here would make doctor report ok for an entry that fails at
  # startup. An UNQUOTED heredoc (<<SECRETS) means the shell already expanded it
  # before zload_secrets ran, so we must substitute to match. .zwork is quoted,
  # .zprivate is not, and they genuinely behave differently.
  local _ze_expand=1
  grep -q "^zload_secrets <<'" "$_ze_file" 2>/dev/null && _ze_expand=0
  while IFS= read -r _ze_line <&3 || [[ -n "$_ze_line" ]]; do
    (( ++_ze_n ))
    [[ "$_ze_line" == sec\|* ]] || continue
    IFS='|' read -r _ze_kind _ze_var _ze_svc _ze_acct <<< "$_ze_line"
    _ze_svc="${_ze_svc:-system}"; _ze_acct="${_ze_acct:-$_ze_var}"
    if (( _ze_expand )); then
      _ze_svc="${_ze_svc//\$USER/$USER}"; _ze_acct="${_ze_acct//\$USER/$USER}"
    fi
    "$_ze_cb" "$_ze_var" "$_ze_svc" "$_ze_acct" "$_ze_n" "$_ze_label"
  done 3< "$_ze_file"
}

# Top level on purpose. zsh has no nested function scope, so defining this
# inside _zsec_ls would make it global anyway while hiding that fact. Declaring
# it here lets the file label arrive as an argument instead of via a global.
_zsec_ls_row() {
  # `st`, not `status`. In zsh `status` is the csh-compat alias for `?` and is
  # integer-readonly-special, so `local status=ok` aborts the function with
  # "read-only variable: status" and every row vanishes. Verified on zsh 5.9.
  # `local -h status` would also work but hides $? inside a function that reads
  # an exit code on the next line, so the rename is the honest fix.
  local var="$1" svc="$2" acct="$3" label="$5" st=ok
  security find-generic-password -s "$svc" -a "$acct" >/dev/null 2>&1 || st=MISSING
  printf '%-32s %-11s %-14s %s\n' "$var" "$label" "$svc" "$st"
}

_zsec_ls() {
  local personal=0
  [[ "${1:-}" == -h || "${1:-}" == --help ]] && { print -r -- "zsec ls [-p]  list registered secrets and their status"; return 0 }
  [[ "${1:-}" == -p || "${1:-}" == --personal ]] && personal=1

  printf '%-32s %-11s %-14s %s\n' NAME FILE SERVICE STATUS
  local f priv="${ZSEC_PRIVATE_FILE:-$ZDOTDIR/.zprivate}"
  for f in "${ZSEC_WORK_FILE:-$ZDOTDIR/.zwork}" "$priv"; do
    (( personal )) && [[ "$f" != "$priv" ]] && continue
    _zsec_each_entry "$f" _zsec_ls_row "${f:t}"
  done
}
```

Change the final `case` to:

```zsh
case "${1:-}" in
  add) shift; _zsec_add "$@" ;;
  ls)  shift; _zsec_ls  "$@" ;;
  *)   _zsec_die "unknown subcommand '${1:-}'"; return 1 ;;
esac
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: `28 passed, 0 failed`.

- [ ] **Step 5: Sanity check against the real config**

Run: `cd ~/.config/zsh && zsh -lic 'zsec ls' | head -5`
Expected: a header row and real secret names with `ok` status. No values.

- [ ] **Step 6: Commit**

```bash
git -C ~/.config add zsh/functions/zsec zsh/tests/zsec.test.zsh
git -C ~/.config commit -m "feat(zsh): add zsec ls"
```

---

### Task 6: `zsec doctor`

**Files:**
- Modify: `functions/zsec`
- Modify: `tests/zsec.test.zsh`

**Interfaces:**
- Consumes: `_zsec_each_entry` from Task 5.
- Produces: nothing later tasks need.

- [ ] **Step 1: Write the failing tests**

Add to `tests/zsec.test.zsh` and call them:

```zsh
# ---------------------------------------------------------------- case 12,13,14
test_doctor_flags_missing() {
  setup_fixtures
  print -r -- "sec|GHOST_TOKEN|$TEST_SERVICE" >> "$ZSEC_WORK_FILE"
  local out code=0; out=$(zsec doctor 2>&1) || code=$?
  assert_eq "12a exits 1 on missing" "1" "$code"
  # Anchored to the MISSING row rather than counting bare name occurrences.
  # A plain `grep -c GHOST_TOKEN` sees 2, because the copy-pasteable fix hint
  # repeats the name, so the count would silently change if that line is ever
  # reworded. This asserts the thing we actually care about.
  assert_eq "12b names the culprit"  "1" "$(print -r -- "$out" | grep -c '^  MISSING .*GHOST_TOKEN')"
}

test_doctor_flags_hex_trap() {
  setup_fixtures; track HEX_TOKEN
  kc_plant "$TEST_SERVICE" HEX_TOKEN $'line1\nline2'
  print -r -- "sec|HEX_TOKEN|$TEST_SERVICE" >> "$ZSEC_WORK_FILE"
  local out code=0; out=$(zsec doctor 2>&1) || code=$?
  assert_eq "13a exits 1 on hex trap" "1" "$code"
  # Pinned to the verdict keyword, not just the name. A bare name grep passes
  # whether the row says HEXTRAP or MISSING, so a misclassification would slip.
  assert_eq "13b names the culprit"   "1" "$(print -r -- "$out" | grep -c '^  HEXTRAP .*HEX_TOKEN')"
}

test_doctor_flags_cross_file_duplicate() {
  setup_fixtures; track DUP_TOKEN
  # Planted, not added through zsec: doctor's hex check reads every entry with
  # `security -g`, which would dialog on a keyring-written item.
  kc_plant "$TEST_SERVICE" DUP_TOKEN doctorsecret
  print -r -- "sec|DUP_TOKEN|$TEST_SERVICE" >> "$ZSEC_WORK_FILE"
  print -r -- "sec|DUP_TOKEN|$TEST_SERVICE" >> "$ZSEC_PRIVATE_FILE"
  local out code=0; out=$(zsec doctor 2>&1) || code=$?
  assert_eq "14a exits 1 on duplicate" "1" "$code"
  assert_eq "14b says DUPLICATE"       "1" "$(print -r -- "$out" | grep -c DUPLICATE)"
  assert_no_leak "14c doctor never prints a value" "doctorsecret" "$out"
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: FAIL on all six new assertions.

- [ ] **Step 3: Implement `doctor`**

Add to `functions/zsec` above the final `case`:

```zsh
# Build the remediation line for a MISSING entry. It must carry --service and
# --account when they are not the defaults: `zsec add VAR -c -f` alone would
# recreate the item at service=system, leaving an orphan, leaving doctor still
# red, and printing "already registered ... left alone", which reads as success.
# Declared on a SEPARATE `local` line from var/svc/acct: in zsh a later
# assignment in the same `local` cannot see an earlier one in that statement.
_zsec_fix_hint() {
  local var="$1" svc="$2" acct="$3"
  local h="zsec add $var -c -f"
  [[ "$svc" != system ]] && h+=" --service ${(q)svc}"
  [[ "$acct" != "$var" ]] && h+=" --account ${(q)acct}"
  print -r -- "$h"
}

# Top level, same reason as _zsec_ls_row. The counters stay global because
# they accumulate across calls, which is what an accumulator is for. The file
# label does not, so it arrives as $5.
_zsec_doctor_row() {
  local var="$1" svc="$2" acct="$3" n="$4" label="$5"
  (( ++_zsec_total ))
  # The NAME half, which doctor used not to check at all. zload_secrets turns
  # this into `export $var=...`; an invalid identifier makes `source` abort and
  # silently drops every secret after it, in a different order each shell start.
  # doctor validated the keychain half exhaustively and reported the whole set
  # healthy while that was happening.
  if [[ ! "$var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    (( _zsec_malformed++ ))
    printf '  %-10s %-30s not a valid shell variable name, %s:%s\n' \
      MALFORMED "${var:-(empty)}" "$label" "$n"
    printf '  %-10s %-30s startup aborts here and loses every secret after it\n' '' ''
    return
  fi
  if [[ -n "${_zsec_seen[$var]:-}" ]]; then
    (( _zsec_dup++ ))
    printf '  %-10s %-30s also declared at %s, %s wins\n' \
      DUPLICATE "$var" "${_zsec_seen[$var]}" "$label"
    return
  fi
  _zsec_seen[$var]="$label:$n"

  # Existence check uses the metadata form, with no -w, so it never touches the
  # value and can never raise an authorization prompt.
  if ! security find-generic-password -s "$svc" -a "$acct" >/dev/null 2>&1; then
    (( _zsec_missing++ ))
    printf '  %-10s %-30s no keychain item for service=%s account=%s\n' MISSING "$var" "$svc" "$acct"
    printf '  %-10s %-30s fix: %s\n' '' '' "$(_zsec_fix_hint "$var" "$svc" "$acct")"
    return
  fi
  # `security -g` prefixes hex-encoded data with 0x and leaves printable values
  # unprefixed. That is the discriminator `-w` cannot provide, because a value
  # that is legitimately all hex digits is indistinguishable in -w output.
  # Verified not to false-positive on 'deadbeef1234'. The value itself is never
  # captured, only whether the 0x tag is present.
  #
  # This DOES read item data, so it can raise the one-time authorization dialog
  # on a keyring-written item, which is every item `zsec add` created. That is
  # the same single Always-Allow that zload_secrets would trigger at the next
  # shell start, not an extra one. An earlier comment here claimed "no second
  # binary, so no ACL prompt", which was wrong: what matters is whether
  # `security` is the binary that WROTE the item, and it is not.
  #
  # Capture the producer's exit status separately. Letting grep's match be the
  # only signal meant a denied authorization, or an item deleted between the two
  # calls, fell through to `ok`. A false `ok` is the one verdict doctor must
  # never give.
  local _g _grc
  _g=$(security find-generic-password -s "$svc" -a "$acct" -g 2>&1 >/dev/null)
  _grc=$?
  if (( _grc != 0 )); then
    (( _zsec_unreadable++ ))
    printf '  %-10s %-30s security could not read it (rc=%s). Authorization denied?\n' \
      UNREADABLE "$var" "$_grc"
    return
  fi
  if print -r -- "$_g" | grep -q '^password: 0x'; then
    (( _zsec_hex++ ))
    printf '  %-10s %-30s value is not printable ASCII, security returns hex\n' HEXTRAP "$var"
    printf '  %-10s %-30s fix: re-store it as ASCII, or stop exporting it\n' '' ''
    return
  fi
  printf '  %-10s %s\n' ok "$var"
}

_zsec_doctor() {
  [[ "${1:-}" == -h || "${1:-}" == --help ]] && {
    print -r -- "zsec doctor  check every registered secret resolves and reads back cleanly"
    print -r -- "             exits 1 if anything is wrong"
    print -r -- "             may raise one keychain authorization dialog per secret"
    print -r -- "             the first time, same as the next shell start would"
    return 0 }

  typeset -gA _zsec_seen=()
  typeset -g _zsec_missing=0 _zsec_hex=0 _zsec_dup=0 _zsec_total=0 _zsec_unreadable=0 _zsec_malformed=0

  local f
  for f in "${ZSEC_WORK_FILE:-$ZDOTDIR/.zwork}" "${ZSEC_PRIVATE_FILE:-$ZDOTDIR/.zprivate}"; do
    [[ -r "$f" ]] || continue
    print -r -- "${f:t}"
    _zsec_each_entry "$f" _zsec_doctor_row "${f:t}"
  done

  print -r -- ""
  print -r -- "$_zsec_total checked, $_zsec_missing missing, $_zsec_hex hex-trapped, $_zsec_unreadable unreadable, $_zsec_dup duplicate, $_zsec_malformed malformed."
  local bad=$(( _zsec_missing + _zsec_hex + _zsec_unreadable + _zsec_dup + _zsec_malformed ))
  # All six, not just the map. These are typeset -g, so leaving the counters
  # behind pollutes the interactive shell on every doctor run.
  unset _zsec_seen _zsec_total _zsec_missing _zsec_hex _zsec_unreadable _zsec_dup _zsec_malformed
  (( bad == 0 ))
}
```

Change the final `case` to add `doctor) shift; _zsec_doctor "$@" ;;`.

- [ ] **Step 4: Run to verify it passes**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: `44 passed, 0 failed`.

- [ ] **Step 5: Run doctor against the real config**

Run: `cd ~/.config/zsh && zsh -lic 'zsec doctor'; echo "exit=$?"`
Expected: every real secret `ok`, summary `22 checked, 0 missing, 0 hex-trapped, 0 unreadable, 0 duplicate, 0 malformed.`, `exit=0`.

- [ ] **Step 6: Commit**

```bash
git -C ~/.config add zsh/functions/zsec zsh/tests/zsec.test.zsh
git -C ~/.config commit -m "feat(zsh): add zsec doctor with missing, hex-trap and duplicate checks"
```

---

### Task 7: Help text

**Files:**
- Modify: `functions/zsec`

**Interfaces:**
- Consumes: nothing.
- Produces: `_zsec_help`, and a real `_zsec_help_add` replacing the Task 2 stub.

- [ ] **Step 1: Replace `_zsec_help_add` and add `_zsec_help`**

In `functions/zsec`, replace the `_zsec_help_add` stub with both functions below. Both use a quoted heredoc (`<<'EOF'`) so `$USER` and the backticks stay literal.

```zsh
_zsec_help() {
  cat <<'EOF'
zsec - manage the secrets your shell loads at startup

HOW IT WORKS
  Every secret has two halves that have to stay in sync:

    VALUE   in the macOS login keychain, never in a file
    NAME    in a manifest line in .zwork (work) or .zprivate (personal)

  At startup zload_secrets reads each name from the manifest, looks it up in
  the keychain, and exports it. When the halves disagree the variable just
  goes missing and nothing says why. zsec writes both halves in one step so
  they cannot drift, and `zsec doctor` catches it if they ever do.

USAGE
  zsec add VAR [options]   store a value and register the name
  zsec ls [-p]             list registered secrets and their status
  zsec doctor              check that every name resolves, exit 1 if not
  zsec help                this text

OPTIONS for add
  -c, --clipboard     take the value from the clipboard
  -p, --personal      target .zprivate instead of .zwork
  -f, --force         overwrite a keychain item that already exists
      --service SVC   keychain service, default: system
      --account ACCT  keychain account, default: same as VAR

  The value comes from the clipboard with -c, from stdin when stdin is a
  pipe, otherwise from a silent double prompt. It is never an argument, so
  it cannot leak into your shell history or into `ps` output.

EXAMPLES
  # You copied a token. Store it as a work secret.
  zsec add GH_PROD_PASSWORD -c

  # Same, but personal.
  zsec add RAILWAY_TOKEN -c -p

  # Type it instead. Prompts twice, echoes nothing.
  zsec add REDASH_API_TOKEN

  # Pipe it from another tool.
  op read "op://Private/Okta/password" | zsec add OKTA_PASSWORD

  # Rotate one you already have.
  zsec add GH_PROD_PASSWORD -c -f

  # The keychain item is filed under a non-default service or account.
  zsec add DD_API_KEY -c --service datadog
  zsec add ANTHROPIC_API_KEY -c -p --service "Claude Code" --account "$USER"

  # What is registered, and does it resolve?
  zsec ls
  zsec doctor

AFTER ADDING
  The variable is not in your current shell yet. Open a new shell, or source
  the file zsec just told you it wrote:
      source ~/.config/zsh/.zwork        # or .zprivate, if you used -p

NOTES
  The first time anything reads a secret you just added, macOS asks you to
  authorize it, once. Click Always Allow and it will not ask again. Either a
  new shell or `zsec doctor` can be what triggers that first read.
  No zsec command ever prints a secret value.
  Manifest edits back the file up to <file>.bak-<timestamp> first.
  Re-adding a name already in the manifest does not duplicate the line.
  Values must be printable ASCII. A newline, tab, accent or emoji is
  refused, because macOS returns those hex-encoded and the startup loader
  would export the hex instead of the secret. `zsec doctor` flags any such
  item that got in by another route.
  doctor cannot find keychain items that have no manifest line. Listing the
  keychain prompts for auth on every item.
EOF
}
```

```zsh
_zsec_help_add() {
  cat <<'EOF'
zsec add VAR [options]   store a value and register the name

OPTIONS
  -c, --clipboard     take the value from the clipboard
  -p, --personal      target .zprivate instead of .zwork
  -f, --force         overwrite a keychain item that already exists
      --service SVC   keychain service, default: system
      --account ACCT  keychain account, default: same as VAR

  The value comes from the clipboard with -c, from stdin when stdin is a
  pipe, otherwise from a silent double prompt. It is never an argument, so
  it cannot leak into your shell history or into `ps` output.

  Values must be printable ASCII. A newline, tab, accent or emoji is
  refused, because macOS returns those hex-encoded and the startup loader
  would export the hex instead of the secret.

EXAMPLES
  # You copied a token. Store it as a work secret.
  zsec add GH_PROD_PASSWORD -c

  # Same, but personal.
  zsec add RAILWAY_TOKEN -c -p

  # Type it instead. Prompts twice, echoes nothing.
  zsec add REDASH_API_TOKEN

  # Pipe it from another tool.
  op read "op://Private/Okta/password" | zsec add OKTA_PASSWORD

  # Rotate one you already have.
  zsec add GH_PROD_PASSWORD -c -f

  # The keychain item is filed under a non-default service or account.
  zsec add DD_API_KEY -c --service datadog
  zsec add ANTHROPIC_API_KEY -c -p --service "Claude Code" --account "$USER"
EOF
}
```

Change the final `case` to:

```zsh
case "${1:-}" in
  add)            shift; _zsec_add    "$@" ;;
  ls)             shift; _zsec_ls     "$@" ;;
  doctor)         shift; _zsec_doctor "$@" ;;
  help|-h|--help) _zsec_help ;;
  "")             print -ru2 -- "usage: zsec {add|ls|doctor|help}   run 'zsec help' for examples"; return 1 ;;
  *)              print -ru2 -- "zsec: unknown subcommand '$1'"
                  print -ru2 -- "usage: zsec {add|ls|doctor|help}   run 'zsec help' for examples"
                  return 1 ;;
esac
```

- [ ] **Step 2: Verify every help surface renders**

Run each and read the output:

```
cd ~/.config/zsh
zsh -lic 'zsec help'
zsh -lic 'zsec add -h'
zsh -lic 'zsec ls -h'
zsh -lic 'zsec doctor -h'
zsh -lic 'zsec' ; echo "no-args exit=$?"
zsh -lic 'zsec bogus' ; echo "bad-subcommand exit=$?"
```

Expected: full help for the first, add-specific help for the second, one or two lines each for the next two, usage plus `exit=1` for the last two. Confirm `$USER` and the backticks around `ps` appear literally, which proves the heredoc is quoted.

- [ ] **Step 3: Confirm the tests still pass**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: `44 passed, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git -C ~/.config add zsh/functions/zsec
git -C ~/.config commit -m "feat(zsh): add zsec help, examples and per-subcommand usage"
```

---

### Task 8: Make `zload_secrets` warn on a failed lookup

**Files:**
- Modify: `functions/zload_secrets:13-27`
- Modify: `tests/zsec.test.zsh`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: nothing.

- [ ] **Step 1: Write the failing test**

Add to `tests/zsec.test.zsh` and call it:

```zsh
# ---------------------------------------------------------------- case 15
test_zload_secrets_warns_on_missing() {
  local err
  err=$(zload_secrets 2>&1 >/dev/null <<SPEC
sec|DEFINITELY_NOT_A_REAL_SECRET_XYZ|$TEST_SERVICE
SPEC
)
  assert_eq "15 warns and names the missing secret" \
    "1" "$(print -r -- "$err" | grep -c DEFINITELY_NOT_A_REAL_SECRET_XYZ)"
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: FAIL on `15 warns and names the missing secret`, want `1` got `0`, because the current code is silent.

- [ ] **Step 3: Implement the warning**

First, immediately after line 1 (`emulate -L zsh`) insert:

```zsh
setopt no_xtrace no_verbose   # `emulate -L zsh` resets neither. Without these,
                   # `zsh -xl`, the standard way to profile this startup, prints
                   # every secret value four times. Measured. local_options
                   # scoping means tracing resumes when the function returns.
```

Then replace lines 13 to 27 of `functions/zload_secrets` with:

```zsh
local tmp bad ugly
tmp=$(mktemp)  || return 1
bad=$(mktemp)  || { rm -f "$tmp"; return 1 }          # else a later failure orphans $tmp
ugly=$(mktemp) || { rm -f "$tmp" "$bad"; return 1 }
# Without this trap, a Ctrl-C mid-startup leaves every value that had already
# resolved sitting in a world-readable-by-this-uid plaintext file under $TMPDIR,
# which macOS does not clear promptly.
# Signals ONLY, plus an explicit rm on the normal path at the bottom. EXIT must
# NOT be in this list, and the reason is subtle enough to be worth writing down.
# An EXIT trap set in a function DOES fire on return, but the function's `local`
# variables are already torn down by the time it runs, so $tmp/$bad/$ugly are
# all empty and `rm -f ""` is a silent no-op. Measured: the trap printed, and
# all three files survived, one of them holding the exported secret in
# plaintext, on every shell start. Making them global would work; keeping them
# local and removing them explicitly is simpler.
trap 'rm -f "$tmp" "$bad" "$ugly"' INT TERM HUP
(
  local kind var a b acct
  while IFS='|' read -r kind var a b; do
    [[ -z "$kind" || "$kind" == \#* ]] && continue
    case "$kind" in
      sec) # Validate the NAME before anything else. `print export ${var}=...`
           # with an invalid identifier makes `source` abort at that line, and
           # every secret written after it is silently lost. The jobs append in
           # completion order, so WHICH ones you lose changes on every shell
           # start. Measured. This check is the only thing stopping the cascade.
           if [[ ! "$var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
             print -r -- "${var:-(empty)}" >> "$ugly"; continue
           fi
           acct="${b:-$var}"
           { local v; v=$(security find-generic-password -s "${a:-system}" -a "$acct" -w 2>/dev/null);
             if [[ -n $v ]]; then print -r -- "export ${var}=${(q)v}" >> "$tmp"
             else                 print -r -- "$var" >> "$bad"; fi; } & ;;
    esac
  done
  wait
)
source "$tmp"
# One warning after `wait`, not inside the parallel jobs, so the lines cannot
# interleave. Silent when everything resolves, which keeps startup quiet.
if [[ -s "$ugly" ]]; then
  print -ru2 -- "zload_secrets: skipped invalid variable name(s): ${(j:, :)${(f)"$(<$ugly)"}}"
  print -ru2 -- "               an invalid name would abort the export and lose other secrets"
fi
if [[ -s "$bad" ]]; then
  print -ru2 -- "zload_secrets: no keychain item for: ${(j:, :)${(f)"$(<$bad)"}}"
  print -ru2 -- "               run 'zsec doctor' for details"
fi
# The normal-return cleanup. See the trap comment above for why this cannot be
# folded into an EXIT trap. These files hold every resolved secret in plaintext.
rm -f "$tmp" "$bad" "$ugly"
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh`
Expected: `45 passed, 0 failed`.

- [ ] **Step 5: Verify the happy path stayed silent**

Run: `cd ~/.config/zsh && zsh -lic 'true' 2>&1 | grep -c zload_secrets`
Expected: `0`. Any other number means a real secret is missing or the warning fires when it should not.

- [ ] **Step 6: Verify startup time did not regress**

Run: `for i in 1 2 3; do /usr/bin/time -p zsh -lic exit; done 2>&1 | grep real`
Expected: roughly 1.1s each, matching the README's stated figure. A jump to 2s or more means something moved onto the read path.

- [ ] **Step 7: Commit**

```bash
git -C ~/.config add zsh/functions/zload_secrets zsh/tests/zsec.test.zsh
git -C ~/.config commit -m "fix(zsh): warn when a keychain lookup fails instead of silently skipping it"
```

---

### Task 9: Document `zsec` in the README

**Files:**
- Modify: `README.md`, the "Secrets model" section around line 76

**Interfaces:**
- Consumes: the finished CLI.
- Produces: nothing.

- [ ] **Step 1: Add a subsection after the existing "Secrets model" prose**

Insert after the paragraph ending "...no `[N] …` job-control chatter." and before the blockquote about `.gitignore`:

```markdown
### Adding a secret

Use `zsec`, which writes the keychain item and the manifest line together so
they cannot drift:

    zsec add GH_PROD_PASSWORD -c      # value from the clipboard, into .zwork
    zsec add RAILWAY_TOKEN -c -p      # personal, into .zprivate
    zsec ls                           # what is registered, and does it resolve
    zsec doctor                       # exits 1 if any secret is missing or unreadable

Run `zsec help` for the full reference. Values must be printable ASCII, since
macOS returns anything else hex-encoded and `zload_secrets` would export the hex.
```

- [ ] **Step 2: Verify the claims in what you just wrote**

Run: `cd ~/.config/zsh && zsh -lic 'zsec help' >/dev/null && zsh -lic 'zsec doctor' >/dev/null && echo "both work"`
Expected: `both work`. Never document a flag without running it.

- [ ] **Step 3: Commit**

```bash
git -C ~/.config add zsh/README.md
git -C ~/.config commit -m "docs(zsh): document zsec in the secrets section"
```

---

## Known coverage gaps

The 15 cases do not cover everything the code does. These are deliberate, and
the reason is given for each. Do not let a green test run imply more than it is.

| Untested path | Why | Mitigation |
|---|---|---|
| `-c` clipboard input | Testing it means writing to the real pasteboard, clobbering whatever the user has copied. Not worth it. | Task 7 Step 2 exercises it by hand. |
| Interactive double prompt | `read -rs` needs a tty, which a piped test run does not have. | Exercise by hand once: `zsec add TMP_TOKEN --service zsec-selftest`, then delete it. |
| Keychain write succeeds, manifest append fails | Needs a file that is readable, has a `zload_secrets <<` block, and fails to write. Contrived to set up. | Reachable by hand: `chmod 400` the fixture and run `zsec add`. Confirm the message prints the line to paste. |
| Target file has no `zload_secrets <<` block | Cheap to add later if it ever fires. | The error message names the file and prints the line. |
| Two `sec\|VAR` lines inside one file | The `_zsec_seen` map is keyed by name across both files, so case 14 exercises the same branch. | Covered by shared code path, not by its own case. |

One trap for anyone adding cases later: the harness points `ZDOTDIR` at an empty
temp directory, deliberately, so `zsec`'s default path resolution cannot reach
the real manifests. That applies to every child process, so a case that shells
out to `zsh -l` or `zsh -i` would start against an empty config and fail in a
confusing way. The plan's `zsh -lic` verification steps are fine because they
run from the terminal, outside the harness. Keep it that way.

## Task 10: Final verification

**Files:** none modified.

- [ ] **Step 1: Full test run from a clean shell**

Run: `cd ~/.config/zsh && zsh tests/zsec.test.zsh; echo "exit=$?"`
Expected: `45 passed, 0 failed`, `exit=0`.

- [ ] **Step 2: Confirm no test residue in the keychain**

Run: `security find-generic-password -s zsec-selftest >/dev/null 2>&1 && echo "LEAK" || echo "clean"`
Expected: `clean`.

- [ ] **Step 3: Confirm no secret value reaches argv anywhere in the source**

Run: `cd ~/.config/zsh && grep -n 'security add-generic-password\|-w "\$' functions/zsec`
Expected: no output. Any hit is a violation of the top global constraint.

- [ ] **Step 4: Confirm the real config is healthy**

Run: `cd ~/.config/zsh && zsh -lic 'zsec doctor'; echo "exit=$?"`
Expected: `22 checked, 0 missing, 0 hex-trapped, 0 unreadable, 0 duplicate, 0 malformed.` and `exit=0`.

- [ ] **Step 5: Confirm the temp-file fixtures never touched the real files**

Run: `cd ~/.config/zsh && ls .zwork.bak-* .zprivate.bak-* 2>/dev/null | wc -l`
Expected: `0` if you never ran a real `zsec add` during development. A non-zero count is fine if you did, but check each backup's diff against the live file before deleting it.

- [ ] **Step 6: Request review**

Invoke the `@code-reviewer` subagent on the full diff before opening anything upstream.
