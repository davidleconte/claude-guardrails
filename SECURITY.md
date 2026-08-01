# Politique de sécurité

## Secrets — règle absolue

**Aucun secret dans ce dépôt.** Les clés et jetons vivent dans `~/.secrets.env` (mode `600`)
et le Keychain macOS. Ne jamais committer une valeur d'authentification (clé API, jeton OAuth,
mot de passe). En cas de fuite accidentelle : **révoquer et faire tourner la clé immédiatement**,
puis purger l'historique.

## Signalement d'une vulnérabilité

Contact : **David Leconte** — <david.leconte1@ibm.com>. Merci de signaler en privé (pas d'issue
publique) et de laisser un délai raisonnable de correction avant toute divulgation.

## Note de risque connue (écosystème)

Le registre des risques de la spécification d'architecture référence un risque **R6** (clé Morph
historiquement en clair) dont la mitigation — rotation + variable d'environnement — est
prioritaire. Voir la feuille de route de la spécification.
