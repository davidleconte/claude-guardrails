# Contribuer

**Projet mono-mainteneur.** Il n'y a pas d'équipe ni de processus de revue formel : inutile de
prétendre le contraire. Proposez un changement par patch ou branche, ou contactez le mainteneur —
David Leconte, [linkedin.com/in/davidleconte](https://www.linkedin.com/in/davidleconte).

## Principes non négociables (ceux-là, oui)

- **Advisory d'abord.** Les hooks et garde-fous *avertissent*, ne bloquent jamais (`exit 0`) ;
  l'enforcement dur vit au push-time.
- **One home per value.** Un fait a un seul foyer. Ne recopiez pas un ADR ou une définition : liez-la.
- **Falsifiabilité.** Aucun chiffre sans sa méthode et ses limites. On ne fige pas un compte de tests
  dans un badge ou une date « vérifié le … » qui pourrira : le compte se re-mesure à l'exécution.
- **Réversibilité.** Toute intégration fournit son interrupteur d'arrêt.

## Avant de proposer un changement

Faites tourner les tests (voir la section *Vérification* du README) ; ils doivent rester verts.
Mettez à jour `CHANGELOG.md` (SemVer) et la documentation impactée.
