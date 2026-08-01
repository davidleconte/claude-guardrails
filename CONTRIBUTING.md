# Contribuer

Merci de votre intérêt. Ce dépôt suit quelques principes non négociables, hérités
de l'écosystème d'optimisation de tokens Claude Code.

## Principes

- **Advisory d'abord.** Les hooks et garde-fous *avertissent*, ils ne bloquent jamais le
  harness (`exit 0`). L'enforcement dur vit au push-time, pas dans la session.
- **One home per value.** Un fait n'a qu'un seul foyer autoritatif. Ne recopiez pas un ADR ou
  une définition : liez-la. Le glossaire est unique (couche écosystème).
- **Falsifiabilité.** Aucun chiffre sans sa méthode et ses limites. Un test qui compte des
  assertions doit afficher le compte exact et daté ; on ne cite jamais un chiffre obsolète.
- **Réversibilité.** Toute intégration fournit son interrupteur d'arrêt.

## Flux de contribution

1. Créez une branche depuis `main`.
2. Ajoutez/mettez à jour les tests ; ils doivent rester **verts** (voir la section Vérification du README).
3. Mettez à jour `CHANGELOG.md` (format SemVer) et la documentation impactée.
4. Ouvrez une PR décrivant le *pourquoi* (pas seulement le *quoi*) ; liez l'ADR concerné s'il existe.

## Style

- Python : stdlib d'abord, dépendances minimales, `exit 0` pour les hooks advisory.
- Shell : `set -euo pipefail` pour les scripts non-hooks ; les hooks restent tolérants.
- Documentation : conforme au standard `AUDIT-DOC-token-economy` (8 dimensions).
