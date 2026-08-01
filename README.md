![statut](https://img.shields.io/badge/statut-actif-brightgreen)
![licence](https://img.shields.io/badge/licence-MIT-informational)

# claude-guardrails — cadre de garde-fous advisory, domaine-agnostique

> **Un moteur unique de gouvernance de session, piloté par des profils déclaratifs et activé par contexte de dépôt.**
> Tous les hooks sont *advisory et non-bloquants* (`exit 0`) ; l'enforcement dur reste au push-time.

**Auteur & mainteneur :** David Leconte — [github.com/davidleconte](https://github.com/davidleconte) · [linkedin.com/in/davidleconte](https://www.linkedin.com/in/davidleconte)
**Statut :** prototype acté · **Version :** 0.1.0

## Sommaire
[Pourquoi](#pourquoi) · [Quickstart](#quickstart) · [Principe](#principe) · [Structure](#structure) · [Profils](#profils) · [Vérification](#vérification) · [Limites](#limites-assumées) · [Gouvernance](#gouvernance)

## Pourquoi
Les hooks quant d'origine mêlaient mécanisme, politique et déclencheur, et **sur-déclenchaient**.
Ce dépôt extrait le mécanisme en un moteur générique : une discipline = un profil JSON ; une
activation = un marqueur de dépôt. Décision : `docs/adr/0003-generalized-guardrails.md` (dans
`claude-automation-setup`).

## Quickstart
```bash
bash test_guardrails.sh               # attendu : tous verts (H1–H9)
python3 engine/guardrails.py status   # profils actifs du dépôt courant
```

## Principe
Trois couches séparées : **mécanisme** (`engine/guardrails.py`, stdlib, `exit 0`), **politique**
(`profiles/<nom>.json`), **activation** (`.guardrails.json` ; **pas de marqueur → no-op silencieux**).

## Structure
```
engine/guardrails.py     moteur (precheck | session-review | policy-drift | status)
hooks/*.sh               câblage PreToolUse/Bash + SessionEnd
profiles/quant.json      reproduit le comportement quant d'origine
profiles/secrets.json    2e profil (démonstration de portabilité)
test_guardrails.sh       harnais de preuve (groupes H1–H9)
```

## Profils
`precheck` (`trigger`, `include`, `exclude`, `rules[]`, `scan_scope`), `session_review`
(`when` + `dispatch[]`), `policy_drift` (`check_cmd`, `requires_*`, `fix_hint`).
Résolution du scope : env `GUARDRAILS_SCOPE` > profil > marqueur > défaut `diff`.

## Vérification
```bash
bash test_guardrails.sh   # le compte exact (groupes H1–H9) s'affiche à l'exécution — pas figé ici
```

## Limites assumées
- `session_review` imprime la checklist **inconditionnellement** (le champ `when` est documentaire).
- Le matching de `trigger` est un glob simple (rate `cd x && pytest`).
- Le profil `secrets` est une **démonstration**, pas un scanner vérifié (préférer gitleaks/trufflehog).

## Gouvernance
[`LICENSE`](LICENSE) (MIT) · [`CHANGELOG.md`](CHANGELOG.md) · [`CONTRIBUTING.md`](CONTRIBUTING.md) ·
[`SECURITY.md`](SECURITY.md) · décision : `claude-automation-setup/docs/adr/0003-generalized-guardrails.md`.

---
*Conforme au standard AUDIT-DOC-token-economy v1.0. Un fait = un foyer.*
