# CONFIG-PROJET : le bloc `contexte:convention`

> Tout ce qui varie d'un projet à l'autre se déclare dans ce bloc, jamais dans un script recopié.
> Un projet ne forke plus un script, il règle une ligne.

Le bloc ouvre `CODEMAP.md`. Les scripts le cherchent d'abord là, puis dans `CLAUDE.md`,
`AGENTS.md`, puis les autres `.md` de la racine. Une ligne par clé, `clé: valeur`, listes séparées
par des virgules. Seule `version` est obligatoire.

```
<!-- contexte:convention
version: 5
profil: application
piliers: CODEMAP.md, TODOS.md, CHANGELOG.md
docs: docs/
archives: archives/
langue: fr
journal: date-titre
seuils: CODEMAP.md=600, CLAUDE.md=250
ajourne: CLAUDE.md=411@2026-09-07
taille-forcee: moyenne
exceptions: secret=tests/test_web_sante.py, lien=machines/**
ecarts: MEMORY.md=pilier assumé, voir docs/decisions/ADR-0002
-->
```

| Clé | Défaut | Rôle |
|---|---|---|
| `version` | 4 si la ligne manque | Version du bloc. Un script plus ancien refuse de tourner et le dit. |
| `profil` | déduit par `ctx-init.sh` | Type de projet, voir `PROFILS-PROJETS.md`. |
| `piliers` | `CODEMAP.md, TODOS.md, CHANGELOG.md` | Les trois piliers. |
| `docs` | `docs/` | Répertoire des fiches. |
| `archives` | `archives/` | Répertoire des archives. |
| `plans` | `plans/` | Répertoire des plans. `plans: docs/plans/` pour un dépôt qui les range ailleurs. Sert à `ctx-rotation.sh --plans` et au contrôle des plans exécutés de l'audit. |
| `langue` | `fr` | Langue de la prose. |
| `journal` | essaie les trois | `date-titre` (`## AAAA-MM-JJ`), `keep-a-changelog` (`## [x] - AAAA-MM-JJ`) ou `crochets` (`[AAAA-MM-JJ] [TYPE]`). |
| `seuils` | ceux de `BUDGET.md` | `fichier=lignes`, un par fichier à relever. |
| `taille-forcee` | aucune | Impose `petite`, `moyenne` ou `grande` à la place de la mesure. |
| `ajourne` | aucun | Dépassement gelé, `fichier=lignes@date`. Il ne doit plus grossir. |
| `exceptions` | aucune | `type=motif`, motif en glob shell, `**` compris. Jugements déjà rendus. |
| `ecarts` | aucun | Écart assumé à la convention, avec sa justification. |

## `taille-forcee`

L'audit mesure la taille du projet (moins de 150 fichiers hors dépendances : `petite`, 150 à 600 :
`moyenne`, au-delà : `grande`). `taille-forcee:` l'impose et les contrôles suivent la valeur forcée.
Quand elle diffère de la mesure, l'audit le dit en information. Une valeur hors des trois est
ignorée, la mesure est gardée.

La migration la pose quand une ancienne ligne `taille:` diffère de la mesure. Elle la note à
confirmer. Si la mesure convient, on retire la ligne. Une ligne `taille:` n'est plus lue depuis la
version 5, l'audit demande de la retirer ou de la passer en `taille-forcee:`.

## `seuils`

`fichier=N` fixe le seuil d'**alerte**. Le blocage suit dans le même rapport que les valeurs par
défaut, arrondi à l'entier : `CODEMAP.md=600` donne une alerte à 600 et un blocage à 800, comme 300
et 400 par défaut. Une valeur non numérique est ignorée.

Clés admises en plus des chemins de fichier :

| Clé | Surface | Défaut alerte / blocage |
|---|---|---|
| `reprise` | bloc de reprise de TODOS | 50 / 80 |
| `cout-reprise` | somme de ce qu'une session charge au départ | 600 / 900 |
| `regles-sans-paths` | règles `.claude/rules/` sans `paths` | 150 / 200 |
| `memoire-auto` | index de la mémoire automatique | 150 / aucun, hors dépôt |

## `ajourne`

Cliquet sur un dépassement déjà là, `fichier=lignes@AAAA-MM-JJ`, entrées séparées par des virgules.
Tant que le fichier ne dépasse pas la valeur gelée, l'alerte ou le blocage ne se dit plus et l'audit
rappelle l'entrée en information. S'il grossit au-delà, c'est un **blocage**. Dès qu'il repasse sous
son seuil d'alerte, l'audit alerte : « retirer l'entrée ». Une entrée illisible ou dont le fichier
n'existe plus donne aussi une alerte.

## `exceptions`

`type=motif`, motif en glob shell, `*` et `**` couvrent aussi les `/`. Un jugement déjà rendu, pas
une désactivation du contrôle.

| Type | Ce qu'il fait taire | Le motif vise | Exemple |
|---|---|---|---|
| `fiche` | fiche de `docs/` absente de l'index | le chemin de la fiche | `fiche=docs/brouillons/**` |
| `lien` | lien mort ou cible introuvable | la cible telle qu'écrite, depuis la racine, ou la page qui porte le lien | `lien=machines/**` |
| `archive` | archive sans en-tête ou hors index | le chemin de l'archive | `archive=archives/2025-*` |
| `secret` | valeur suspecte d'un secret | le fichier qui la porte | `secret=tests/test_web_sante.py` |
| `agent` | agent sans `model:` ou avec un identifiant complet | le chemin de l'agent | `agent=.claude/agents/ancien.md` |
| `verite` | affirmation du texte que `ctx-verite.sh` ne retrouve pas (chemin, script, option, commande, comptage) | l'affirmation telle qu'écrite | `verite=scripts/ancien.sh` |

`ctx-verite.sh` lit aussi `lien` : un motif `lien` couvre les mêmes affirmations qu'un motif
`verite`. Pour un comptage, le motif est le répertoire, avec ou sans `/` final.

Les sous-modules ne se déclarent pas, ils se lisent dans `.gitmodules`.
