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
  # stderr to a FILE, not `err=$(zload_secrets ...)`. zload_secrets exports into
  # its CALLER, and a command substitution forks, so the $(...) form throws the
  # export away: 19b would read an empty NINETEEN_TOKEN and fail even against a
  # perfect fix, leaving the cascade this case exists to pin completely untested.
  # Verified both ways before changing it.
  local ef; ef=$(mktemp) || { print -ru2 -- "harness: mktemp failed"; exit 1 }
  TMPFILES+=("$ef")
  zload_secrets 2>"$ef" >/dev/null <<SPEC
sec|BAD-NAME|$TEST_SERVICE
sec|NINETEEN_TOKEN|$TEST_SERVICE
SPEC
  local err; err=$(<"$ef")
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

print -r -- "zsec tests"
test_add_creates_both_halves
test_add_is_idempotent
test_add_refuses_existing_without_force
test_add_force_overwrites
test_line_form_service_only
test_line_form_service_and_account
test_rejects_empty_value
test_rejects_interior_newline
test_rejects_accented
test_preserves_surrounding_spaces
test_ls_lists_without_values
test_doctor_flags_missing
test_doctor_flags_hex_trap
test_doctor_flags_cross_file_duplicate
test_zload_secrets_warns_on_missing
test_add_refuses_unplaceable_manifest_line
test_rotate_to_new_service_rewrites_the_line
test_zload_secrets_skips_an_invalid_name
test_doctor_flags_a_malformed_name
test_xtrace_does_not_leak_values
test_zsec_add_xtrace_does_not_leak
test_force_rotates_a_foreign_item

print -r -- ""
print -r -- "$PASS passed, $FAIL failed"
(( FAIL == 0 ))
