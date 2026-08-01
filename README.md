![statut](https://img.shields.io/badge/statut-actif-brightgreen)
![tests](https://img.shields.io/badge/tests-21%2F21%20(H1--H9)-brightgreen)
![version](https://img.shields.io/badge/version-0.1.0-blue)
![licence](https://img.shields.io/badge/licence-MIT-lightgrey)

# claude-guardrails — cadre de garde-fous advisory, domaine-agnostique

> **Un moteur unique de gouvernance de session, piloté par des profils déclaratifs et activé par contexte de dépôt.**
> Tous les hooks sont *advisory et non-bloquants* (`exit 0`) ; l'enforcement dur reste au push-time.

**Auteur & mainteneur :** David Leconte — IBM Worldwide watsonx.data Tiger Team · <david.leconte1@ibm.com>
**Statut :** prototype acté · **Version :** 0.1.0 · **Dernière revue :** 2026-08-01

## Sommaire
[Pourquoi](#pourquoi) · [Quickstart](#quickstart) · [Principe](#principe) · [Structure](#structure) · [Profils](#profils) · [Vérification](#vérification) · [Limites](#limites-assumées) · [Gouvernance](#gouvernance)

## Pourquoi
Les hooks quant d'origine mêlaient mécanisme, politique et déclencheur, et **sur-déclenchaient**
(rappels hors contexte). Ce dépôt extrait le mécanisme en un moteur générique : une discipline =
un profil JSON ; une activation = un marqueur de dépôt. Décision : `docs/adr/0003-generalized-guardrails.md`
(dans `claude-automation-setup`).

## Quickstart
```bash
bash test_guardrails.sh          # attendu : 21/21 (H1–H9), exit 0
python3 engine/guardrails.py status   # liste les profils actifs du dépôt courant
```

## Principe
Trois couches séparées : **mécanisme** (`engine/guardrails.py`, Python stdlib, `exit 0`),
**politique** (`profiles/<nom>.json`, données), **activation** (`.guardrails.json` à la racine
d'un dépôt ; **pas de marqueur → no-op silencieux** — le correctif du sur-déclenchement).

## Structure
```
engine/guardrails.py     moteur (precheck | session-review | policy-drift | status)
hooks/*.sh               câblage PreToolUse/Bash + SessionEnd
profiles/quant.json      reproduit le comportement quant d'origine
profiles/secrets.json    2e profil (preuve de portabilité)
test_guardrails.sh       harnais de preuve (H1–H9, 21 assertions)
```

## Profils
Un profil déclare jusqu'à trois blocs : `precheck` (`trigger`, `include`, `exclude`, `rules[]`,
`scan_scope`), `session_review` (`when` + `dispatch[]`), `policy_drift` (`check_cmd`, `requires_*`,
`fix_hint`). Résolution du scope : env `GUARDRAILS_SCOPE` > profil > marqueur > défaut `diff`.

## Vérification
```bash
bash test_guardrails.sh   # 21 assertions (H1–H9) — vérifié le 2026-08-01
```
Couvre : déclenchement (H1), silence hors-trigger (H2), **no-op sans marqueur (H3)**, code propre
(H4), exclusion des tests (H5), dispatch (H6), portabilité `secrets` (H7), skip prérequis (H8),
override de scope (H9).

## Limites assumées
- `session_review` imprime la checklist **inconditionnellement** (le champ `when` est documentaire).
- Le matching de `trigger` est un glob simple (rate `cd x && pytest`).
- Le profil `secrets` est une **démonstration**, pas un scanner vérifié (préférer gitleaks/trufflehog en `check_cmd`).

## Gouvernance
Licence [`LICENSE`](LICENSE) (MIT) · versions [`CHANGELOG.md`](CHANGELOG.md) ·
[`CONTRIBUTING.md`](CONTRIBUTING.md) · [`SECURITY.md`](SECURITY.md) ·
décision : `claude-automation-setup/docs/adr/0003-generalized-guardrails.md`.

---
*Conforme au standard AUDIT-DOC-token-economy v1.0. Un fait = un foyer.*
