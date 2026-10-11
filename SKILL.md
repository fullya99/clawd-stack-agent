---
name: clawd-stack-agent
description: "Tient la documentation de contexte d'un projet vraie et courte d'une session à l'autre, quel que soit son type ou sa taille, pour Hermes Agent, OpenClaw et Codex. Six modes : init installe la convention, planifier écrit un plan sourcé qui porte sa propre reprise, cloture range la session avant un redémarrage de contexte, relance dit où on en était, audit vérifie AGENTS.md et CLAUDE.md contre le code, migrer remet une ancienne convention à jour. Trois piliers CODEMAP.md, TODOS.md et CHANGELOG.md, plus docs/ et archives/, réglés par le bloc contexte:convention, et la mémoire propre à l'agent rangée à chaque clôture. Se déclenche sur : clôture, fin de session, reprends, où on en était, fais un plan, planifie, audite le AGENTS.md, la doc gonfle, TODOS est trop long, archive ce qui est obsolète, doc vivante, migrer la convention. Pas pour rédiger ou corriger un texte, c'est style-redaction."
license: MIT
platforms: [linux, macos, windows]
version: 1.0.0-rc.2
author: fullya99
metadata:
  hermes:
    tags: [memory, skills, documentation, session, housekeeping, context-budget, planning, audit]
---

# clawd-stack-agent

> Le dépôt seul doit suffire à reprendre le travail. Ce qui ne vit que dans la conversation n'existe pas.

Tu tournes en continu, mais ta session se remet à zéro. Ce qui n'est pas écrit avant ce moment-là
n'existe plus après. Charge d'abord le skill de style avant d'écrire, `style-redaction-agent` ou
`style-redaction`. S'il manque : ton direct, aucun tiret cadratin, aucun point-virgule, langue de
la prose du projet.

## Le socle

- Trois piliers à la racine : `CODEMAP.md` (où), `TODOS.md` (maintenant), `CHANGELOG.md` (ce qui a changé).
- `CLAUDE.md` ou `AGENTS.md` porte ce qui est vrai tout le temps, court, sans état ni récit.
- `docs/` ne contient que du vrai. `archives/` absorbe le reste, avec un en-tête, et ne se lit jamais comme source de vérité.
- Le bloc `contexte:convention` (`version: 5`), dans `CODEMAP.md`, déclare les chemins réels, le profil et les seuils.
- Devant chaque ligne, demande : qui est propriétaire de cette phrase ?

## Choisir le mode

Chez Hermes, le skill s'invoque par `/clawd-stack-agent <mode>`. Chez Codex, par `$clawd-stack-agent`
suivi du mode. Chez OpenClaw, par son nom dans la demande. Sans mode donné, l'intention décide.
Lis le fichier du mode, lui seul.

| Mode | Intention | Lire |
|---|---|---|
| init | installer la convention, le kit manque | `references/MODE-INIT.md` |
| cloture | fin de session, avant un redémarrage de contexte, la doc gonfle | `references/MODE-CLOTURE.md` |
| relance | début de session, où on en était, prompt de redémarrage générique | `references/MODE-RELANCE.md` |
| planifier | faire un plan, cadrer une idée | `references/MODE-PLANIFIER.md` |
| audit | `CLAUDE.md` ou `AGENTS.md` trop long ou faux | `references/MODE-AUDIT.md` |
| migrer | remettre une ancienne convention à jour | `references/MODE-MIGRER.md` |

Pas ce skill : rédiger ou corriger un texte, c'est le skill de style. Ajouter une fonction ou
corriger un bug ne demande aucun mode. Un `CLAUDE.md` à réécrire de zéro sans audit passe par `references/BUDGET.md`.

## Résoudre `$SKILL`, une fois par session

Les scripts vivent dans le skill, pas dans le projet. Tu travailles depuis le projet, donc un chemin
relatif ne résout pas. Résous le chemin avant le premier appel :

```bash
ANCETRES="$(d="$PWD"; while [ "$d" != "/" ]; do echo "$d/.agents/skills/clawd-stack-agent"; d="$(dirname "$d")"; done)"

SKILL="$(for d in \
  $(find "$HOME/.hermes/skills" "$HOME/.openclaw" -maxdepth 4 -type d -name clawd-stack-agent 2>/dev/null) \
  $(find skills -maxdepth 2 -type d -name clawd-stack-agent 2>/dev/null) \
  $ANCETRES \
  "$HOME/.codex/skills/clawd-stack-agent" "$HOME/.agents/skills/clawd-stack-agent" \
  "$HOME/.claude/skills/clawd-stack-agent"; do
  [ -f "$d/scripts/ctx-audit.sh" ] && echo "$d" && break
done)"
[ -n "$SKILL" ] || echo "skill introuvable, fais les etapes a la main sans le script"
```

Observable : `$SKILL` pointe un dossier qui contient `scripts/ctx-audit.sh`. Le premier `find` couvre
Hermes et OpenClaw, le second un workspace déplacé, `$ANCETRES` Codex. L'ordre : `references/RESOLUTION.md`.

## Ta mémoire d'agent

Ta mémoire est réinjectée à chaque appel, et rien ne la purge tout seul. Un fait faux te trompe à
chaque session sans bruit. La clôture te la fait relire en entier. Chaque phrase a un propriétaire
et un seul :

| Ce que tu viens d'apprendre | Où ça va |
|---|---|
| un fait sur ce projet, une décision, une règle du projet | le dépôt : carte, fiche, ADR, `CLAUDE.md` ou `AGENTS.md` |
| une préférence durable de l'utilisateur, valable partout | `USER.md` |
| un fait durable sur la machine, les accès, les pièges | `MEMORY.md` |
| qui tu es, ton ton, tes refus | `SOUL.md`, sur demande explicite seulement |

`MEMORY.md`, `USER.md` et `SOUL.md` vivent hors du dépôt et ne s'y commitent jamais. Aucun fait de
projet ne s'écrit dans `MEMORY.md`. Détail, passes de purge et ménage de tes skills dans
`references/MEMOIRE-AGENT.md`. Sans aucune de ces bases sur la machine, fais la partie projet, dis
que tu sautes la partie mémoire et n'invente pas de chemins.

## Orchestrer

La session principale cadre, arbitre et valide. Tout ce qui se délègue part au rôle le moins cher
qui tient son critère de fin : `explorateur`, `controleur`, `executant`, `developpeur`, `chercheur`,
`expert`, `relecteur`. Confie-le aux sous-agents de la plateforme s'il y en a, sinon découpe en
étapes vérifiées une à une. Rôles, critères et brief dans `references/DELEGATION.md`.

## Invariants

- Rien de vrai ne se perd. Ce qui sort d'une surface part dans `archives/` avec sa raison, jamais en suppression silencieuse.
- Aucun commit ni push sans l'opérateur, aucun secret dans un fichier tracké.
- `archives/` ne se lit que par `ctx-archeo.sh`.
- Un outil de recherche externe accélère, il n'est jamais un prérequis.
- Aucune doc écrite depuis une supposition, aucune affirmation connue fausse laissée pour plus tard.
- Ne touche pas à `SOUL.md` de ta propre initiative, ne supprime pas un skill ou un pan de mémoire sans le dire.
- La langue suit le skill de style, sinon celle déclarée par le bloc `contexte:convention`.

## Références

| Fichier | Quand le lire |
|---|---|
| `references/MODE-*.md` | un fichier par mode, celui du tableau ci-dessus |
| `references/MEMOIRE-AGENT.md` | clôture : où va quoi entre le dépôt et ta mémoire, ménage de tes skills |
| `references/DELEGATION.md` | déléguer à un rôle, ou découper en étapes sans sous-agents |
| `references/MULTI-DEPOTS.md` | parent à sous-modules, plusieurs dépôts |
| `references/MEMOIRE-AUTO.md` | le projet est aussi travaillé avec Claude Code, drainer sa mémoire automatique |
| `references/CONVENTION.md` | spécification des trois piliers et propriétaire de chaque savoir |
| `references/CONFIG-PROJET.md` | chaque clé du bloc `contexte:convention`, défaut et exemple |
| `references/BUDGET.md` | seuils, geste par fichier qui déborde, `CLAUDE.md` sans audit |
| `references/ZONES.md` | un répertoire mérite sa carte |
| `references/DOCS-SYSTEM.md` | organisation de `docs/`, ADR, index |
| `references/ARCHIVAGE.md` | archiver, corriger ou supprimer, rotation des journaux |
| `references/PROFILS-PROJETS.md` | adapter la convention au type de projet |
| `references/HANDOFF.md` | test « prêt pour un contexte neuf » |
| `references/RESOLUTION.md` | la boucle `$SKILL` rend vide ou la mauvaise version |
| `references/plan/PLAN.md` | rédiger un plan, ossature et format d'une tâche |
| `references/plan/EXECUTION.md` | exécuter un plan, équipe et délégation selon la plateforme |
| `references/plan/PROMPT.md` | un bloc à coller dans une session neuve, si on le demande |
| `references/plan/RECHERCHE.md` | phase de recherche d'un plan |
| `references/plan/TYPES-DE-PLAN.md` | triage, sections propres à chaque type |
| `references/audit-md/les-quatre-etages.md` | choisir où sort un bloc de `CLAUDE.md` |
| `references/audit-md/criteres-classement.md` | trancher un cas limite de classement |
| `references/audit-md/anti-patterns.md` | justifier une suppression |
| `references/audit-md/modeles.md` | gabarit de fichier racine et de fiche |
| `references/audit-md/fichiers-agents.md` | le dépôt déclare des sous-agents |
| `references/audit-md/memoire-de-l-agent.md` | une ligne de ta mémoire touche au sujet audité |
| `templates/` | gabarits des piliers, zones, ADR et du plan |

## Scripts

Tous s'appellent par `bash "$SKILL/scripts/<nom>"`.

| Script | Rôle |
|---|---|
| `ctx-init.sh` | détecte le terrain, crée ce qui manque sans rien écraser |
| `ctx-audit.sh` | mesure les surfaces et contrôle la convention |
| `ctx-rotation.sh` | fait tourner les journaux |
| `ctx-archive.sh` | déplace un fichier vers `archives/` avec son en-tête |
| `ctx-archeo.sh` | seule porte de lecture de `archives/` |
| `ctx-migrer.sh` | simule puis applique le passage en version 5 |
| `ctx-verite.sh` | confronte la doc au code |
| `ctx-commun.sh` | fonctions partagées, ne s'appelle pas seul |
| `verif-refs.sh`, `verif-agents.sh` | références mortes, déclarations d'agents |
