# zsec: a CLI for the shell secrets manifest

**Status:** design approved, implementation plan pending
**Date:** 2026-09-16

## Goal

One autoloaded zsh function, `zsec`, that adds a secret to the macOS keychain and
registers it in `.zwork` or `.zprivate` in a single step, lists what is
registered, and verifies that the two halves still agree.

## Why

Adding a secret today takes two manual steps that can drift apart:

1. put the value in the keychain (`keyring set system VAR`)
2. hand-edit `.zwork` to add a `sec|VAR` line

Two problems make this worth tooling, and neither is the typing.

**A failed lookup is silent.** `functions/zload_secrets:21` writes the export
only when the lookup returns something:

```zsh
v=$(security find-generic-password -s "${a:-system}" -a "$acct" -w 2>/dev/null)
[[ -n $v ]] && print -r -- "export ${var}=${(q)v}" >> "$tmp"
```

A manifest line pointing at a keychain item that does not exist exports nothing
and prints nothing. You find out hours later when some tool fails for an
unrelated-looking reason. `functions/keyring_export:5` warns in the same
situation. `zload_secrets` does not. That contradicts the fail-loudly rule the
rest of this config follows.

**Getting a value in safely is fiddly.** Keeping the secret out of shell
history and out of an agent transcript takes deliberate care every time. That is
the kind of step that gets done sloppily under time pressure.

**A non-ASCII value is exported as hex.** Found while probing the write path,
not predicted. `security find-generic-password -w` hex-encodes any value holding
a byte outside printable ASCII, and `zload_secrets` uses that call, so such a
secret reaches the environment as a hex string with nothing said. See "The hex
trap" below.

Audits of all 22 current secrets found no drift and no hex case, so both risks
are latent rather than active. The volume (22 secrets accumulated since the
2026-06 rewrite, so roughly one or two a month) clears the rule of three.

## Design

### Placement

`functions/zsec`, body only, no shebang, same shape as `zload_secrets`.
`.zshrc:6-7` already adds `functions/` to `fpath` and autoloads every file in it
by basename, so the command exists with no wiring.

Subcommands dispatch through a `case`. One file.

### Keychain access: who writes, who reads, and why it matters

A macOS keychain item's ACL names the binary allowed to read its data. Cross a
binary boundary and macOS raises a GUI authorization dialog. Measured here:

| write | read | result |
|---|---|---|
| `keyring` | `keyring get` | silent |
| `security` | `security -w` | silent |
| `keyring` | `security -w` | prompts once, then Always Allow is permanent |
| `security` | `keyring get` | prompts |

The rule that falls out: read a value with whatever wrote it.

`zsec` writes with `keyring set` over stdin and verifies the write by reading
back with `keyring get`. Neither step crosses the boundary, so an add is silent.

`zload_secrets` reads with `security` at every shell start, which does cross it.
That costs exactly one dialog per secret, the first time, and Always Allow makes
it permanent because production items are never deleted and recreated. That is
the entire authorization cost of the tool.

#### Why not write with `security` and avoid the boundary entirely

Because `security add-generic-password -w "$value"` puts the secret in argv, and
argv is not private on a managed machine.

This was tried and reverted. macOS Endpoint Security delivers full argv on every
exec to any registered extension, and BSM audit records it too. Both are live on
this machine: an EDR agent is registered as an activated Endpoint Security
extension, and `auditd` is running. Writing with `security` would copy every
secret into an EDR telemetry stream that leaves the host and is retained
centrally, readable by people who could never invoke `security` as this user.

The tempting counter-argument, which is wrong, is that once the ACL admits
`/usr/bin/security` any same-user process can read these items anyway, so a
sub-second argv window adds nothing. That measures the wrong axis. The exposure
is not a capability an attacker gains locally, it is the secret being copied
into a durable off-host record. The observation window is sub-second. The
retention window is months.

There is no third option. `security add-generic-password -w` cannot take the
value from stdin: it ignores the pipe, and driving it over a real pty makes it
store an empty value with no prompt at all. Both were tested. `-A` never enters
into it, since `security` is not the writer.

#### What this means for tests

Test values are fake, so argv does not matter for them. The only cases needing
`security` to read a fixture are `doctor`'s hex checks, and those plant the item
with `security add-generic-password` directly. Everything else goes through
`zsec add` and reads back with `keyring get`. The suite is therefore silent.

### Command surface

```
zsec add VAR [-c] [-p] [-f] [--service SVC] [--account ACCT]
zsec ls [-p]
zsec doctor
zsec help
```

`-h` and `--help` work on the top level and on each subcommand. No arguments
prints a short usage block to stderr and exits 1. An unknown subcommand prints
the same block plus the offending word.

### `zsec add`

Value source, in precedence order. Never from argv, and `--value` is a hard
error that explains why.

1. `-c` reads `pbpaste`
2. stdin is not a tty, so read to EOF and strip one trailing newline
3. otherwise prompt twice with `read -s` and require a match

Then:

- Validate `VAR` against `^[A-Za-z_][A-Za-z0-9_]*$`. Reject an empty value.
- Reject any value containing a byte outside printable ASCII, tested with
  `[[ $value == *[^\ -~]* ]]`. See "The hex trap" below for why. This runs
  before anything is written, so a rejected value leaves no partial state.
- If the keychain item exists and `-f` was not passed, exit 1. Overwriting a
  live secret because of a typo costs more than the friction of a flag.
- Write with `keyring set` over stdin, then read the value back with
  `keyring get`, the same binary that wrote it, and compare sha256 against the
  intended value. Reading back with `security` would be a closer match to what
  `zload_secrets` does, but it crosses the ACL boundary and would raise a dialog
  on every single add. The pre-flight check should make
  this impossible to fail, so a failure here means an assumption broke and the
  command stops.
- Append the manifest line only when no `sec|VAR` line already exists, so
  re-running changes nothing.
- Back up the target file to `<file>.bak-<timestamp>` before writing. Both files
  are untracked, so git offers no undo. `.gitignore:14` already excludes
  `*.bak-*`.

Two edge cases in that sequence:

- The keychain write can succeed and the manifest append still fail, for example
  when the file has no `SECRETS` terminator to insert before. `zsec` reports
  both facts, prints the exact line to paste, and exits 1. It does not roll the
  keychain write back, because the value is the hard part to recover.
- If the target file exists but contains no `zload_secrets <<` block, `zsec`
  refuses rather than guessing where the line goes. Creating the file from
  nothing is a bootstrap problem and stays out of scope.

### The hex trap

Measured on this machine, not assumed. `security find-generic-password -w`
returns the password hex-encoded whenever it contains any byte outside
printable ASCII (`0x20` to `0x7E`). Confirmed hex-triggering: newline, tab,
accented characters, emoji. Confirmed safe: spaces anywhere including leading
and trailing, and the full ASCII punctuation set. The stored bytes are intact
in every case, so the problem is `-w`'s presentation, not storage. `security -g`
reports the same values with a `0x` prefix, which is how `doctor` detects them.

`zload_secrets` uses `security -w`. So a secret containing any of those bytes
gets exported as a hex string rather than its value, with nothing to indicate
it. A scan of all 22 current secrets found none affected, so this is latent.

Two ways out were considered. Teaching `zload_secrets` to detect and decode hex
fails because a value that is genuinely a lowercase hex string is
indistinguishable from an encoded one by looking at `-w` output alone. So `zsec`
refuses the value at write time, which is the only moment the value is in hand
and the user can do something about it. The startup path stays fast and
unchanged.

`doctor` can still detect an already-stored hex case, because `security -g`
distinguishes them where `-w` cannot: it prefixes genuinely hex-encoded data
with `0x`, and leaves a legitimately-all-hex-digits value unprefixed.

The cost is that a genuinely accented password cannot be stored. That is worth
it against silently exporting the wrong string.

The manifest line matches the `zload_secrets` grammar:

| condition | line |
|---|---|
| service is `system`, account equals VAR | `sec\|VAR` |
| account equals VAR | `sec\|VAR\|SVC` |
| otherwise | `sec\|VAR\|SVC\|ACCT` |

Output names the file it touched and says whether the item was created or
updated. It never prints the value.

### `zsec ls`

```
$ zsec ls
NAME                            FILE        SERVICE   STATUS
GH_PROD_PASSWORD                .zwork      system    ok
DD_API_KEY                      .zwork      datadog   ok
ANTHROPIC_API_KEY               .zprivate   Claude Code  ok
```

Both files by default. `-p` limits output to `.zprivate`. No values, ever.

### `zsec doctor`

Four checks. Exit 1 when any fail, so it works as a pre-flight.

1. Every manifest entry resolves to a keychain item.
2. Every value survives the `security -w` read path, tested with the `0x`
   marker that `security -g` prints for hex-encoded data. This catches hex-trap
   items added outside `zsec`. It uses no second binary, so it cannot trip the
   ACL prompt described above, and it does not false-positive on a value that is
   legitimately all hex digits.
3. No `VAR` appears in both files, where the second silently wins.
4. No `VAR` appears twice inside one file.

Check 2 is the only one that inspects secret data, and it never captures the
value itself, only whether `security -g` tagged it `0x`. Nothing but the name
and a verdict is printed.

Each failure prints the command that fixes it:

```
$ zsec doctor
.zwork
  ok         JENKINS_TOKEN
  MISSING    FOO_TOKEN      no keychain item for service=system account=FOO_TOKEN
                            fix: zsec add FOO_TOKEN -c -f
.zprivate
  ok         RAILWAY_TOKEN
  DUPLICATE  GHTOKEN        also declared in .zwork:22, .zprivate wins

22 checked, 1 missing, 1 duplicate.
```

Orphaned keychain items with no manifest line stay out of scope. Enumerating
them needs `security dump-keychain`, which prompts for auth on every item. The
help text says so rather than implying the check is complete.

### Help text

`zsec help` prints this. The mental model goes first because the two-halves
split is the part nobody guesses.

```
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
  The variable is not in your current shell yet. Open a new shell, or:
      source ~/.config/zsh/.zwork

NOTES
  No zsec command ever prints a secret value.
  Manifest edits back the file up to <file>.bak-<timestamp> first.
  Re-adding a name already in the manifest does not duplicate the line.
  Values must be printable ASCII. A newline, tab, accent or emoji is
  refused, because macOS returns those hex-encoded and the startup loader
  would export the hex instead of the secret. `zsec doctor` flags any such
  item that got in by another route.
  doctor cannot find keychain items that have no manifest line. Listing the
  keychain prompts for auth on every item.
```

`zsec add -h` prints the `OPTIONS for add` block and the examples that use
`add`. `zsec doctor -h` and `zsec ls -h` print their own two-line summary plus
sample output.

### Error messages

Every failure names the cause and the next action. No traceback, always a
non-zero exit.

```
zsec: GH_PROD_PASSWORD already exists in the keychain (service: system).
      Pass -f to overwrite it, or pick a different name.

zsec: refusing to store an empty value for GH_PROD_PASSWORD.
      The clipboard is empty. Copy the secret first, then re-run.

zsec: 'gh-prod' is not a valid shell variable name.
      Use letters, digits and underscores, and do not start with a digit.

zsec: refusing to store GH_PROD_PASSWORD, the value is not printable ASCII.
      It contains a newline, tab, accent or emoji. macOS hands those back
      hex-encoded, so the startup loader would export the hex string instead
      of your secret, with no warning. Nothing was written.

zsec: verification failed for GH_PROD_PASSWORD.
      The value was stored but does not read back correctly, so an assumption
      in zsec is wrong. The keychain item was left as it is and the manifest
      was NOT updated. Please report this.

zsec: --value is not supported on purpose.
      A value passed as an argument is visible to any process via `ps`.
      Use -c for the clipboard, or pipe the value in on stdin.
```

### `zload_secrets` fix

`functions/zload_secrets:21` gains a failure branch. The lookups run as parallel
background jobs, so writing warnings straight to stderr would interleave them.
Failures append to a second temp file inside the subshell, and after `wait` the
parent prints one stderr line naming everything that went missing. The happy
path stays silent, which is what commit 66ae494 was for.

This ships whether or not the rest of `zsec` does.

## Non-goals

- Removing or unregistering a secret. Hand-edit and `zsec doctor`.
- Detecting orphaned keychain items, for the auth-prompt reason above.
- A `_zsec` zsh completion. Worth doing later, not part of this.
- Rotation reminders or expiry tracking.
- Any change to the startup read path beyond the warning.

## Testing

Test-first. One new file, `tests/zsec.test.zsh`, run with `zsh tests/zsec.test.zsh`.
It covers the `zload_secrets` warning too (case 12), since that change is part
of the same work. This is the first test in the repo, so the harness stays
plain: a counter, an `assert` helper, and a trap for cleanup.

Isolation, layered so that no single mistake reaches real data:

- `ZSEC_WORK_FILE` and `ZSEC_PRIVATE_FILE` environment overrides, defaulting to
  the real paths, pointed at temp fixtures during tests.
- `setup_fixtures` runs once at top level as well as per case, so a case that
  forgets to call it writes to a stale temp file rather than the live manifest.
- `mktemp` failures abort the run. Unchecked, an empty override would collapse
  back to the real path through zsec's own `:-` default.
- `ZDOTDIR` is pointed at an empty temp directory, so even the default-resolution
  path inside `zsec` cannot reach the user's files.
- Keychain writes go to a throwaway service, `zsec-selftest`, removed in a trap.
  Real secrets are never written. `doctor` reads them, which is why it also gets
  a leak assertion.

Cases:

1. create a new secret, keychain item and manifest line both appear
2. re-adding the same name is a no-op, no duplicate line
3. adding an existing name without `-f` exits 1 and leaves both halves alone
4. `-f` overwrites and reports "updated"
5. `--service` alone produces `sec|VAR|SVC`
6. `--service` plus `--account` produces `sec|VAR|SVC|ACCT`
7. an empty value exits 1 before touching anything
8. a value with an interior newline exits 1 and writes neither half
9. a value with an accented character exits 1 and writes neither half
10. a value with leading and trailing spaces round-trips byte for byte
11. `doctor` exits 1 on a manifest line with no keychain item
12. `doctor` exits 1 on a hex-trap item planted directly with `security add` (planted that way so `doctor`'s `security -g` check reads it without a dialog)
13. `doctor` exits 1 on a name declared in both files
14. `-p` writes to the private fixture, not the work one
15. `zload_secrets` prints a warning naming a missing secret

## Acceptance criteria

- `zsec add`, `ls`, `doctor`, `help` all work in a fresh login shell with no
  extra wiring.
- No zsec code path puts a secret value in argv. Verified by reading the source.
- No zsec command prints a secret value. This is the one constraint that is easy
  to assert and easy to forget, so the harness carries an `assert_no_leak`
  helper and the cases for `add`, `ls` and `doctor` each call it (1c, 11b, 14c).
- A value outside printable ASCII is refused before either half is written.
  Covered by tests 8 and 9.
- `zsec doctor` exits 0 against the current real config, which has 22 secrets,
  no drift, and no hex-trap items as of this date.
- `zsh tests/zsec.test.zsh` passes, and every test has been watched fail first.
- A missing secret at startup produces exactly one stderr warning naming it.
- Startup time stays at roughly 1.1s, since nothing was added to the read path.
