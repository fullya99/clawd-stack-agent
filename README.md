# clawd-stack-agent

Un skill qui tient la documentation de contexte d'un projet vraie et courte d'une session à
l'autre. Il marche sur **Hermes Agent**, **OpenClaw** et **Codex**, au standard
[agentskills.io](https://agentskills.io/specification).

L'idée tient en une phrase : **si une information ne vit que dans la conversation, elle n'existe
pas.** Ta session se remet à zéro, ce qui n'est pas écrit avant a disparu après.

Il remplace trois paquets, `cloture-agent`, `deep-plan-agent` et `clawd-audit-md-agent`. Un seul
dossier à installer, un seul à mettre à jour. Sur Claude Code, la même chose existe sous forme de
plugin, `clawd-stack`.

## Les six modes

| Mode | Ce qu'il fait |
|---|---|
| `init` | installe la convention dans un projet, sans rien écraser |
| `planifier` | écrit un plan sourcé, validé avant d'être écrit, qui porte sa propre reprise |
| `cloture` | range la session avant un redémarrage de contexte, et relit ta mémoire d'agent |
| `relance` | dit où on en était en ne lisant que le strict nécessaire |
| `audit` | raccourcit `CLAUDE.md` ou `AGENTS.md` en prouvant chaque ligne contre le code |
| `migrer` | remet une ancienne convention à jour, sur une branche, sans rien perdre |

Chez Hermes, `/clawd-stack-agent <mode>`. Chez Codex, `$clawd-stack-agent` suivi du mode. Chez
OpenClaw, par son nom dans la demande. Sans mode, l'intention décide.

## Ce que la convention pose

Trois piliers à la racine du projet.

| Fichier | Question |
|---|---|
| `CODEMAP.md` | Où ça se trouve, et qu'est-ce qui touche quoi ? |
| `TODOS.md` | Qu'est-ce que je fais maintenant ? |
| `CHANGELOG.md` | Qu'est-ce qui a changé, et comment revenir en arrière ? |

Plus `docs/`, qui ne contient que du vrai, et `archives/`, qui absorbe le reste avec un en-tête.
Un bloc `contexte:convention` dans `CODEMAP.md` déclare les chemins, les seuils et la langue du
projet. Chaque fichier a un budget de taille mesuré par un script, parce qu'une doc vraie mais
trop longue est une doc perdue.

Côté agent, il range aussi ce que tu portes en propre : `MEMORY.md` relu en entier à chaque
clôture, `USER.md` mis à jour des corrections de l'utilisateur, tes skills auto-créés sans doublon
ni secret. `SOUL.md` ne bouge que sur demande explicite.

## Installation

Le skill est un dossier. Il se pose là où ta plateforme lit ses skills, par un clone, et se met à
jour par un `git pull`.

**Hermes Agent**

```bash
git clone https://github.com/fullya99/clawd-stack-agent.git \
  ~/.hermes/skills/housekeeping/clawd-stack-agent
```

Le dossier de catégorie est du rangement, le scan est récursif. Hermes expose le skill comme
commande dès l'installation.

**OpenClaw**

```bash
git clone https://github.com/fullya99/clawd-stack-agent.git \
  ~/.openclaw/workspace/skills/clawd-stack-agent
```

Si ton workspace n'est pas à l'emplacement par défaut, regarde `agents.defaults.workspace` dans
`~/.openclaw/openclaw.json`.

**Codex**

```bash
git clone https://github.com/fullya99/clawd-stack-agent.git \
  .agents/skills/clawd-stack-agent
```

Pour tous tes dépôts, clone dans `~/.agents/skills/clawd-stack-agent` à la place. Codex remonte
l'arborescence pour trouver `.agents/skills/`. Invoque-le par `$clawd-stack-agent`.

### Pourquoi le clone et pas `hermes skills install`

L'installeur officiel d'Hermes a refusé l'ancien paquet `cloture-agent`, et ça ne se contourne pas.
Mesuré le 2026-08-13 sur une installation réelle :

```
Decision: BLOCKED - Blocked (community source + dangerous verdict, 27 findings).
--force does not override a dangerous verdict.
rules: agent_config_mod, hermes_config_mod
```

Ni `--force`, ni `--yolo`, ni l'ajout du dépôt aux dépôts de confiance ne lèvent un verdict
`dangerous`. Le scanner ne se trompe pas sur le fond : un skill qui dit à l'agent de relire et de
corriger sa mémoire, et dont les scripts écrivent des fichiers de contexte, porte la signature
d'une attaque par empoisonnement de mémoire. Ce paquet-ci porte la même signature, il serait donc
sans doute bloqué de la même façon. Ce n'est pas vérifié, il n'y a pas d'Hermes sur la machine où
il a été fabriqué. Déguiser les noms serait de l'évasion de scanner, on ne le fait pas. Un skill
qui range ta mémoire d'agent s'installe en le lisant, par clone.

Chez OpenClaw, aucun scan de ce type n'est documenté, le clone suffit. Chez Codex, le clone est la
voie normale.

## Les scripts, utilisables seuls

Bash et git suffisent. Aucune dépendance, aucun serveur MCP, aucun accès réseau.

```bash
bash scripts/ctx-init.sh --dry-run      # voir ce qui serait créé
bash scripts/ctx-audit.sh --budget      # mesurer le budget de chaque surface
bash scripts/ctx-audit.sh --strict      # sortie non nulle s'il reste un blocage, pour la CI
bash scripts/ctx-verite.sh              # confronter la doc au code
bash scripts/ctx-rotation.sh --dry-run  # voir ce que la rotation du journal déplacerait
bash scripts/ctx-migrer.sh              # simuler le passage en version 5
bash scripts/verif-refs.sh --format=md CLAUDE.md AGENTS.md   # références mortes
```

## Ce qu'il ne fait pas

Il ne résume pas ta session, le but est de rendre le dépôt exact. Il ne commite pas, ne pousse pas,
ne supprime rien en douce. Il ne devine pas : ce qu'il ne peut pas vérifier, il le demande. Il n'a
pas encore été éprouvé en conditions réelles sur Hermes ni sur OpenClaw, installe-le en le lisant.

## Licence

MIT.
