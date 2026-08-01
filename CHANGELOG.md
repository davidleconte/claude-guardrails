# Changelog

Format : [Keep a Changelog](https://keepachangelog.com) · [SemVer](https://semver.org).

## [0.1.0] — 2026-08-01
### Ajouté
- Moteur générique `engine/guardrails.py` (precheck / session-review / policy-drift / status).
- Profils `quant` et `secrets` ; activation par marqueur `.guardrails.json`.
- Harnais `test_guardrails.sh` (groupes H1–H9).
- Documentation Tier-1 : README, LICENSE (MIT), CONTRIBUTING, SECURITY.
### Corrigé
- Documentation : le compte d'assertions cité était obsolète (« 17 / H1–H7 ») ; la suite couvre
  désormais H1–H9. Le compte n'est plus figé en dur — il s'affiche à l'exécution des tests.
