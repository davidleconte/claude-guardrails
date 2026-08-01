#!/usr/bin/env bash
# ab-equivalence.sh — prove behavioural equivalence between the ORIGINAL quant
# hook (tier1-gate.sh) and the NEW generic engine (precheck, quant profile),
# on a shared adversarial corpus, at EQUAL scope (whole-repo).
#
# It compares the SET of (relative-file, line) detections — deliberately
# abstracting away output format and the "clean heartbeat" line, which are
# known, documented differences. Divergence in the detection set is the only
# thing that would signal a real regression.
#
# Usage: bash ab-equivalence.sh /path/to/tier1-gate.sh /path/to/engine/guardrails.py
set -uo pipefail
ORIG="${1:?chemin de tier1-gate.sh requis}"
ENGINE="${2:?chemin de engine/guardrails.py requis}"

CORPUS="$(mktemp -d)"; trap 'rm -rf "$CORPUS"' EXIT
mk(){ mkdir -p "$CORPUS/$(dirname "$1")"; printf '%b' "$2" > "$CORPUS/$1"; }

# --- shared adversarial corpus (relative paths matter for exclusion rules) ---
mk a_fit.py            'import x\nX = StandardScaler().fit_transform(df)\n'          # a_fit.py:2
mk b_rng.py            'import numpy as np\nnp.random.seed(0)\nq = np.random.randn(4)\n'  # :2,:3
mk c_state.py          'clf = RandomForest(random_state=None)\n'                     # c_state.py:1
mk clean.py            'import numpy as np\nrng = np.random.default_rng(1)\nv = rng.standard_normal(3)\n'  # none
mk nested/deep.py      'y = pipe.fit_transform(Z)\n'                                 # nested/deep.py:1
mk tests/test_leak.py  'X = sc.fit_transform(df)\n'                                  # excluded (tests/)
mk fixtures/fix.py     'X = sc.fit_transform(df)\n'                                  # excluded (fixtures/)
mk .venv/lib/pkg.py    'np.random.seed(1)\n'                                         # excluded (.venv/)
mk vendor/site-packages/dep.py 'clf = M(random_state=None)\n'                        # excluded (site-packages/)
mk helper_test.py      'X = sc.fit_transform(df)\n'                                  # excluded (_test.py)

# marker so the engine activates the quant profile
printf '{"profiles":["quant"],"scan_scope":"repo"}\n' > "$CORPUS/.guardrails.json"

OUT_ORIG="$(printf '{}' | QUANT_GATE_SCAN_DIR="$CORPUS" bash "$ORIG" 2>&1 1>/dev/null)"
OUT_NEW="$(printf '{}' | GUARDRAILS_REPO="$CORPUS" GUARDRAILS_SCOPE=repo GUARDRAILS_CMD="pytest" python3 "$ENGINE" precheck 2>&1 1>/dev/null)"

CORPUS="$CORPUS" OUT_ORIG="$OUT_ORIG" OUT_NEW="$OUT_NEW" python3 - <<'PY'
import os, re, sys
corpus = os.environ["CORPUS"].rstrip("/") + "/"
orig, new = os.environ["OUT_ORIG"], os.environ["OUT_NEW"]

def orig_set(text):
    s = set()
    for m in re.finditer(r'(/[^\s:]+):(\d+):', text):
        p, ln = m.group(1), m.group(2)
        if p.startswith(corpus):
            s.add((p[len(corpus):], ln))
    return s

def new_set(text):
    s = set()
    for line in text.splitlines():
        m = re.match(r'\s+(\S+):(\d+)(?:\s|$)', line)
        if m:
            s.add((m.group(1), m.group(2)))
    return s

O, N = orig_set(orig), new_set(new)
only_o = sorted(O - N)
only_n = sorted(N - O)
both   = sorted(O & N)

def fmt(s): return ", ".join(f"{f}:{l}" for f, l in s) or "∅"
print("  Détections ORIGINAL (tier1-gate) :", len(O), "->", fmt(sorted(O)))
print("  Détections NOUVEAU  (engine)     :", len(N), "->", fmt(sorted(N)))
print("  ── Communes                      :", len(both), "->", fmt(both))
print("  ── Seulement ORIGINAL            :", fmt(only_o))
print("  ── Seulement NOUVEAU             :", fmt(only_n))
expected = {("a_fit.py","2"),("b_rng.py","2"),("b_rng.py","3"),("c_state.py","1"),("nested/deep.py","1")}
print()
print("  Attendu (corpus)                 :", len(expected), "->", fmt(sorted(expected)))
ok_equiv = (not only_o) and (not only_n)
ok_expect = (O == expected) and (N == expected)
print()
print("  VERDICT équivalence O≡N          :", "ÉQUIVALENTS ✓" if ok_equiv else "DIVERGENCE ✗")
print("  VERDICT vs attendu               :", "CONFORMES ✓" if ok_expect else "ÉCART ✗")
sys.exit(0 if (ok_equiv and ok_expect) else 1)
PY
rc=$?
echo
[ $rc -eq 0 ] && echo "  A/B EQUIVALENCE: PASS ✓ (mêmes détections, à scope égal)" || echo "  A/B EQUIVALENCE: FAIL ✗ (voir divergences ci-dessus)"
exit $rc
