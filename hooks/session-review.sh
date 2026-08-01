#!/usr/bin/env bash
# session-review.sh — SessionEnd advisory. NON-BLOCKING (exit 0).
# Prints the governance checklist for the repo's active profiles (non-spawning).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
exec python3 "$HERE/../engine/guardrails.py" session-review
