# guardrails — cadre de garde-fous advisory, domaine-agnostique

Prototype généralisant les hooks de gouvernance quant (`tier1-gate` / `session-end-review`
/ `tier-drift-audit`) en un moteur **piloté par profils déclaratifs** et **activé par
contexte de dépôt**. Tous les hooks restent **advisory et non-bloquants** (`exit 0`) ;
l'enforcement dur reste au push-time.

## Principe

Trois couches séparées :

- **Mécanisme** — `engine/guardrails.py` (Python 3, stdlib seule). Scanne, avertit, sort 0.
- **Politique** — `profiles/<nom>.json` (données, pas de code). Ce qui est propre à un domaine.
- **Activation** — un marqueur `.guardrails.json` à la racine d'un dépôt sélectionne les profils.
  **Pas de marqueur → no-op silencieux.** C'est ce qui empêche la gouvernance de se déclencher
  dans des dépôts sans rapport (le défaut corrigé par rapport aux hooks quant d'origine).

## Structure

```
guardrails/
  engine/guardrails.py        moteur générique (precheck | session-review | policy-drift | status)
  hooks/precheck-gate.sh      PreToolUse/Bash  → engine precheck
  hooks/session-review.sh     SessionEnd       → engine session-review
  hooks/policy-drift.sh       SessionEnd       → engine policy-drift
  profiles/quant.json         reproduit le comportement quant existant
  profiles/secrets.json       2ᵉ profil (preuve de portabilité : scan de secrets pré-commit)
  .guardrails.json            marqueur d'exemple (à déposer à la racine d'un dépôt)
  hooks.json                  câblage format plugin (${CLAUDE_PLUGIN_ROOT})
  settings.snippet.json       câblage fusion settings.json ($HOME)
  test_guardrails.sh          harnais de preuve (H1–H7, 17 assertions)
```

## Installation

1. Copier `guardrails/` où vous voulez (p. ex. `~/guardrails`).
2. Fusionner `settings.snippet.json` dans `~/.claude/settings.json` (ajuster les chemins).
   Le `precheck-gate` n'a **pas** de filtre `if` : le moteur matche le `trigger` de chaque
   profil contre la commande réelle → il coexiste avec `rtk hook claude` et un éventuel
   `tier1-gate` dans le même tableau `PreToolUse`/`Bash`.
3. Dans chaque dépôt à gouverner, déposer un `.guardrails.json` :
   ```json
   { "profiles": ["quant"], "scan_scope": "diff" }
   ```
   `scan_scope` : `diff` (fichiers changés, défaut) | `repo` (tout l'arbre).

## Profils

Un profil déclare jusqu'à trois blocs :

- `precheck` — `trigger` (glob sur la commande, ex. `pytest*`, `git commit*`), `include`
  (globs de fichiers), `exclude` (regex de chemins), `rules[]` = `{pattern, label, severity}`,
  et un `scan_scope` optionnel (`repo` | `diff`) qui **prime sur le marqueur** — utile quand
  une discipline doit balayer tout l'arbre (ex. quant : `repo`, comme le `tier1-gate` d'origine).
- `session_review` — `when` (rappel) + `dispatch[]` = `{agent, prompt}` (non-spawning : imprime).
- `policy_drift` — `check_cmd` (commande de vérif) + `fix_hint`, plus des gardes optionnelles
  `requires_files[]` / `requires_cmds[]` : si un prérequis manque, le check est **sauté
  silencieusement** (un prérequis absent = « ne peut pas tourner », PAS « dérive »).

Résolution du `scan_scope` : env `GUARDRAILS_SCOPE` (tests) > `precheck.scan_scope` du profil >
`scan_scope` du marqueur > défaut `diff`.

Override par dépôt : placer un profil dans `<repo>/.guardrails.d/<nom>.json` (prioritaire
sur la bibliothèque partagée `profiles/`).

## Vérification

```bash
bash test_guardrails.sh      # 17 assertions, exit 0 = OK
```

Couvre : déclenchement quant sur motifs (H1), silence hors-trigger (H2), **no-op sans marqueur
(H3, le correctif clé)**, silence sur code propre (H4), exclusion des tests (H5), dispatch de
revue (H6), et **portabilité** via le profil `secrets` dans un autre dépôt (H7).

## Limites assumées (prototype)

- `session_review` imprime la checklist des profils actifs **inconditionnellement** ; le champ
  `when` est documentaire (détecter « ce qui a été touché » demanderait de parser le transcript).
- `scan_scope: repo` (défaut du profil quant) attrape les problèmes préexistants mais peut être
  bruyant sur un très gros dépôt ; `diff` est plus léger au prix de rater un fichier inchangé.
- Le matching de `trigger` est un glob simple sur la commande : il rate les formes composées
  (`cd x && pytest`, `python -m pytest`). À élargir par profil si besoin.
- `precheck` sans filtre `if` s'exécute à chaque commande Bash : le fast-path (marche
  filesystem, sans `git`) sort en quelques stats quand aucun marqueur n'est présent.
- Le profil `secrets` est une **démonstration** de portabilité, pas un scanner vérifié :
  pour de la détection de secrets sérieuse, préférer un outil dédié (gitleaks, trufflehog)
  branché comme `check_cmd`.
- Statut : **acté** — voir `docs/adr/0003-generalized-guardrails.md` (dans claude-automation-setup).
