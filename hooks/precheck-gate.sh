#!/usr/bin/env bash
# precheck-gate.sh — PreToolUse/Bash advisory gate. NON-BLOCKING (exit 0).
# Reads the hook event JSON on stdin, resolves the active guardrails profiles for
# the current repo, and scans changed files for the profiles whose `trigger`
# matches the command about to run. Warns on stderr; never denies.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
exec python3 "$HERE/../engine/guardrails.py" precheck
