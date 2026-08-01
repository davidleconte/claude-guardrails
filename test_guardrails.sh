#!/usr/bin/env bash
# test_guardrails.sh — PROOF harness for the generic engine.
# Plants fixtures in throwaway git repos, drives each subcommand with mocked
# events, asserts the advisory behaviour. exit 0 = all pass, 1 = any fail.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
ENGINE="$HERE/engine/guardrails.py"
fail=0
ck(){ if eval "$2"; then echo "    ✓ $1"; else echo "    ✗ $1"; fail=1; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkrepo(){ mkdir -p "$1"; ( cd "$1" && git init -q && git config user.email t@t && git config user.name t ); }

# --- fixture 1: quant repo opted in, dirty python ---
Q="$TMP/quant"; mkrepo "$Q"
printf '{"profiles":["quant"],"scan_scope":"repo"}\n' > "$Q/.guardrails.json"
printf 'from sklearn.preprocessing import StandardScaler\nX = StandardScaler().fit_transform(df)\nimport numpy as np\ny = np.random.randn(5)\n' > "$Q/model.py"

echo "  H1 · quant precheck fires on fit_transform + unpinned RNG when trigger matches"
out="$(printf '{}' | GUARDRAILS_REPO="$Q" GUARDRAILS_CMD="pytest -q" python3 "$ENGINE" precheck 2>&1 1>/dev/null)"; rc=$?
ck "warns on fit_transform" 'printf "%s" "$out" | grep -q "fit sur TRAIN"'
ck "warns on unpinned RNG"   'printf "%s" "$out" | grep -q "RNG non épinglé"'
ck "names model.py"          'printf "%s" "$out" | grep -q "model.py"'
ck "exits 0 (non-blocking)"  "[ $rc -eq 0 ]"

echo "  H2 · quant precheck STAYS SILENT when the command does not match the trigger"
out="$(printf '{}' | GUARDRAILS_REPO="$Q" GUARDRAILS_CMD="ls -la" python3 "$ENGINE" precheck 2>&1 1>/dev/null)"
ck "no output for a non-pytest command" '[ -z "$out" ]'

echo "  H3 · a repo WITHOUT .guardrails.json is a silent no-op (fixes over-firing)"
N="$TMP/plain"; mkrepo "$N"
printf 'X = scaler.fit_transform(df)\n' > "$N/m.py"
out="$(printf '{}' | GUARDRAILS_REPO="$N" GUARDRAILS_CMD="pytest" python3 "$ENGINE" precheck 2>&1 1>/dev/null)"
ck "precheck silent (no active profile)" '[ -z "$out" ]'
out="$(printf '{}' | GUARDRAILS_REPO="$N" python3 "$ENGINE" session-review 2>&1 1>/dev/null)"
ck "session-review silent (no active profile)" '[ -z "$out" ]'

echo "  H4 · quant precheck stays quiet on clean code"
C="$TMP/clean"; mkrepo "$C"
printf '{"profiles":["quant"],"scan_scope":"repo"}\n' > "$C/.guardrails.json"
printf 'import numpy as np\nrng = np.random.default_rng(7)\nX = rng.standard_normal(10)\n' > "$C/model.py"
out="$(printf '{}' | GUARDRAILS_REPO="$C" GUARDRAILS_CMD="pytest" python3 "$ENGINE" precheck 2>&1 1>/dev/null)"
ck "no warning on clean code" '! printf "%s" "$out" | grep -q "signal"'

echo "  H5 · test files are excluded (no self-flagging)"
T="$TMP/onlytests"; mkrepo "$T"
printf '{"profiles":["quant"],"scan_scope":"repo"}\n' > "$T/.guardrails.json"
mkdir -p "$T/tests"; printf 'X = scaler.fit_transform(df)\n' > "$T/tests/test_model.py"
out="$(printf '{}' | GUARDRAILS_REPO="$T" GUARDRAILS_CMD="pytest" python3 "$ENGINE" precheck 2>&1 1>/dev/null)"
ck "tests/ excluded from scan" '! printf "%s" "$out" | grep -q "signal"'

echo "  H6 · session-review prints the quant dispatch for an active quant repo"
out="$(printf '{}' | GUARDRAILS_REPO="$Q" python3 "$ENGINE" session-review 2>&1 1>/dev/null)"; rc=$?
ck "mentions pnl-attribution" 'printf "%s" "$out" | grep -q "quant-pnl-attribution-specialist"'
ck "mentions risk-manager"    'printf "%s" "$out" | grep -q "quant-risk-manager"'
ck "exits 0"                  "[ $rc -eq 0 ]"

echo "  H7 · PORTABILITY — the secrets profile fires on git commit, in a different repo"
S="$TMP/app"; mkrepo "$S"
printf '{"profiles":["secrets"],"scan_scope":"repo"}\n' > "$S/.guardrails.json"
printf 'AWS_KEY = "AKIAIOSFODNN7EXAMPLE"\napi = "sk-abcdefghijklmnop1234567890"\n' > "$S/config.py"
out="$(printf '{}' | GUARDRAILS_REPO="$S" GUARDRAILS_CMD="git commit -m wip" python3 "$ENGINE" precheck 2>&1 1>/dev/null)"; rc=$?
ck "warns on AWS key"      'printf "%s" "$out" | grep -q "AWS Access Key"'
ck "warns on sk- key"      'printf "%s" "$out" | grep -q "sk-… en clair"'
ck "quiet on non-commit cmd" '[ -z "$(printf "%s" "{}" | GUARDRAILS_REPO="$S" GUARDRAILS_CMD="ls" python3 "$ENGINE" precheck 2>&1 1>/dev/null)" ]'
ck "exits 0" "[ $rc -eq 0 ]"

echo ""
if [ "$fail" = 0 ]; then echo "  ALL GUARDRAILS TESTS PASSED ✓"; else echo "  GUARDRAILS TESTS FAILED ✗"; fi
exit $fail
