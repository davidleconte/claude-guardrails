#!/usr/bin/env bash
# policy-drift.sh — SessionEnd advisory. NON-BLOCKING (exit 0).
# Runs each active profile's `policy_drift.check_cmd`; warns if config drifted.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
exec python3 "$HERE/../engine/guardrails.py" policy-drift
