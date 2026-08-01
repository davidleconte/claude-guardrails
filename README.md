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
  (globs de fichiers), `exclude` (regex de chemins), `rules[]` = `{pattern, label, severity}`.
- `session_review` — `when` (rappel) + `dispatch[]` = `{agent, prompt}` (non-spawning : imprime).
- `policy_drift` — `check_cmd` (commande de vérif) + `fix_hint`.

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
- `precheck` en `scan_scope: repo` peut être bruyant sur un gros dépôt → préférer `diff`.
- Parsing regex : motifs à calibrer par profil (sévérité `low` pour les incertains).
- Statut : **proposé**. Une fois validé en usage, promouvoir la décision en `docs/adr/0003`.
