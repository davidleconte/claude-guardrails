# Politique de sécurité

## Secrets — règle absolue

**Aucun secret dans ce dépôt.** Clés et jetons vivent dans `~/.secrets.env` (mode `600`) et le
Keychain macOS. En cas de fuite accidentelle : **révoquer et faire tourner la clé immédiatement**,
puis purger l'historique.

## Signalement

Projet **mono-mainteneur, sans engagement de délai** (pas de SLA de correction : ce serait fictif).
Signalez en privé au mainteneur — David Leconte,
[linkedin.com/in/davidleconte](https://www.linkedin.com/in/davidleconte) — de préférence avant
toute divulgation publique.

## Risque connu (écosystème)

La spécification d'architecture référence un risque **R6** (clé Morph historiquement en clair) dont
la mitigation — rotation + variable d'environnement — reste prioritaire.
