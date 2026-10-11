# MÉMOIRE-AGENT : où va quoi, entre le dépôt et toi

> Référence détaillée de la passe mémoire de la clôture. Le résumé est dans `SKILL.md`.

Chez un agent de session, comme Claude Code, il n'y a qu'un endroit où écrire : le dépôt. Chez toi,
il y en a quatre, et trois t'appartiennent. C'est ce qui rend cette convention différente, et c'est
le seul endroit où elle peut vraiment déraper.

## Où tu tournes, et où sont tes fichiers

Détecte la plateforme avant tout, les chemins en dépendent.

```bash
for base in "$HOME/.hermes" "$HOME/.openclaw/workspace"; do
  [ -d "$base" ] && echo "trouve : $base"
done
```

| | Hermes Agent | OpenClaw |
|---|---|---|
| Identité | `~/.hermes/SOUL.md` | `<workspace>/SOUL.md` |
| Profil utilisateur | `~/.hermes/memories/USER.md` | `<workspace>/USER.md` |
| Mémoire | `~/.hermes/memories/MEMORY.md` | `<workspace>/MEMORY.md` |
| Journal du jour | néant | `<workspace>/memory/AAAA-MM-JJ.md` |
| Skills | `~/.hermes/skills/<categorie>/<nom>/` | `<workspace>/skills/<nom>/` |
| Historique | `~/.hermes/state.db`, SQLite FTS5 | store de session |

Le workspace d'OpenClaw est `~/.openclaw/workspace` par défaut, mais il se configure dans
`~/.openclaw/openclaw.json` sous `agents.defaults.workspace`. Vérifie avant d'écrire, un agent
multi-workspace a un dossier par agent. Si aucune des deux bases n'existe, tu tournes ailleurs :
fais la partie projet, dis que tu sautes la partie mémoire, n'invente pas de chemins.

Observable : la boucle nomme au moins une base, ou tu as dit que tu sautes la mémoire.

**`/new`, `/reset` et `/clear` ne touchent pas ta mémoire sur disque.** Chez Hermes, `/new` ouvre
une session neuve, `/reset` en est un alias, `/clear` fait la même chose en nettoyant l'écran. Chez
OpenClaw, tu te réveilles à neuf à chaque session. `MEMORY.md`, `USER.md` et `SOUL.md` sont là après
comme avant. Ce que la coupure emporte, c'est le contexte de conversation, donc tout ce qui n'a été
que dit. La clôture ne protège pas ta mémoire d'un `/new`, elle fait que le disque contienne ce que
la conversation savait.

## Les quatre surfaces

| Surface | À qui | Chargée quand | Durée de vie |
|---|---|---|---|
| Le dépôt du projet | au projet | quand on travaille dessus | celle du projet |
| `SOUL.md` | à toi | premier emplacement du prompt, toujours | quasi permanente |
| `USER.md` | à l'utilisateur | à chaque appel, étage volatile | longue |
| `MEMORY.md` | à toi | à chaque appel, étage volatile | à purger en continu |

Le journal quotidien d'OpenClaw, `memory/AAAA-MM-JJ.md`, est une cinquième surface mais d'une autre
nature. C'est du brut, daté, non relu. Il alimente, il ne fait pas autorité.

## Deux `MEMORY.md` qui ne sont pas le tien

Le nom prête à confusion, et `references/CONVENTION.md` en parle sans savoir que tu existes.

- Un `MEMORY.md` à la racine d'un projet est un ancien quatrième pilier de la convention. Il se
  répartit chez les propriétaires, voir `references/MODE-MIGRER.md`. Il n'a rien à voir avec le tien.
- La mémoire automatique de Claude Code, un index `MEMORY.md` hors dépôt, ne concerne ce projet que
  s'il est aussi travaillé avec cet outil. Son drainage est dans `references/MEMOIRE-AUTO.md`, tu
  ne le touches que si tu le trouves.

Le tien vit hors du dépôt, sous `~/.hermes/memories/` ou à la racine du workspace OpenClaw. Il ne se
commite pas, et rien ne se recopie d'un côté vers l'autre. Un fait sur ce projet appartient au
dépôt, un fait sur la machine ou sur l'utilisateur appartient à l'agent.

## La question qui tranche

Pas « est-ce important », tout est important sur le moment. La bonne question :

> **Cette phrase sera-t-elle vraie et utile dans une session qui parle d'autre chose ?**

Si oui, elle est à toi. Si elle n'a de sens que dans ce projet, elle appartient au dépôt.

Un exemple qui se trompe souvent. « Le build de ce projet passe par `make release` et pas par
`npm run build` » est un fait de projet, il va au CODEMAP. « Sur cette machine, `make` est GNU make
4.4 et le `make` de macOS casse les recettes avec `.ONESHELL` » est un fait d'environnement, il va
dans `MEMORY.md`. Les deux parlent de `make`, et pourtant un seul te suivra ailleurs.

## Ce qui va dans `MEMORY.md`

Des faits durables sur le monde autour de toi, pas sur un projet.

- L'outillage disponible et ses versions, quand ça a une conséquence.
- Les accès et où sont les secrets, jamais leur valeur.
- Les pièges de la machine, du réseau, du système.
- Ce que tu as appris à tes dépens et qui resservira n'importe où.

Ce qui n'y va pas, et qui y finit quand même si on n'y prend pas garde : le résumé de ce qu'on a
fait aujourd'hui, l'état d'avancement d'un projet, une liste de tâches, une décision technique et
son pourquoi. Tout ça a un propriétaire dans le dépôt.

## Ce qui va dans `USER.md`

Les préférences de la personne, valables partout. Comment elle veut qu'on lui parle, ce qu'elle
refuse, ses conventions, son fuseau, ses outils. Et surtout : **chaque correction qu'elle t'a faite**.
Une correction qui ne finit pas écrite se répétera, et se faire corriger deux fois sur la même chose
est la façon la plus sûre de perdre sa confiance.

Une préférence qui ne vaut que pour un projet n'y va pas. Elle va dans le `CLAUDE.md` ou l'`AGENTS.md`
de ce projet.

## Ce qui va dans `SOUL.md`, et pourquoi tu n'y touches pas

C'est ton identité. Ton ton, ce que tu es, ce que tu refuses. Elle occupe le premier emplacement de
ton prompt système, donc elle conditionne tout le reste.

**Tu ne la modifies que sur demande explicite.** Jamais parce que tu as déduit quelque chose sur
toi-même au fil d'une conversation. Un agent qui réécrit sa propre identité à partir de ses
observations dérive, et la dérive est invisible depuis l'intérieur.

## La purge, la partie que personne ne fait

`MEMORY.md` est réinjecté à chaque appel. Un fait inutile s'y paie indéfiniment, un fait faux te
fait te tromper indéfiniment et sans bruit.

À chaque clôture, relis-le **en entier**. Quatre passes, dans cet ordre.

1. **Faux.** Corrige. C'est la priorité, loin devant tout le reste.
2. **Périmé.** Supprime. Pas d'archivage, `MEMORY.md` n'est pas un journal. Si la disparition
   compte, elle laisse une ligne dans le CHANGELOG du projet concerné.
3. **Mal placé.** Un fait de projet remonte dans le dépôt, où il servira à quiconque le lit,
   humain compris.
4. **En double.** Fusionne. Deux formulations du même fait finiront par se contredire, et tu ne
   sauras plus laquelle croire.

Le test de taille est simple et il marche : **si tu ne relirais pas ce fichier en entier de bon
cœur, il est trop gros.** Coupe.

### Par l'outil ou à la main

Si ta plateforme expose un outil de mémoire, passe par lui plutôt que d'éditer le fichier
directement. Chez Hermes c'est l'outil `memory`, qui prend plusieurs opérations d'un coup et connaît
la limite de taille du fichier, un ajout au-delà se fait refuser. Cette limite est ta friction utile,
mais elle n'arbitre rien : elle te force à couper au moment où tu ajoutes, pas à relire ce qui est
déjà là. Les quatre passes ci-dessus restent à ta charge.

Le compactage de contexte, lui, ne purge rien. Il compresse l'historique de la conversation, pas ta
mémoire sur disque. Ne compte pas sur lui.

Et si tu as déjà une tâche périodique qui fait une introspection, un rapport du matin par exemple,
branche la clôture dessus plutôt que d'en lancer une deuxième à côté. Deux relectures de la même
mémoire dans la même journée, c'est du temps payé deux fois.

## Les skills que tu t'écris

Une classe d'artefact que les agents de session n'ont pas. Tu en crées, tu les modifies, tu peux les
supprimer, et rien ne fait le ménage derrière toi.

Un skill mérite d'exister si sa connaissance a été **difficile à obtenir** et qu'elle **resservira**.
Les deux, pas l'un ou l'autre. Sinon c'est une note, et une note va dans `MEMORY.md`.

Inventaire de ce que tu as écrit, avant de trier :

```bash
# Hermes
find "$HOME/.hermes/skills" -name SKILL.md | wc -l
# OpenClaw
find "$HOME/.openclaw/workspace/skills" -name SKILL.md | wc -l
```

Observable : un nombre, puis pour chaque skill touché cette session un verdict parmi les quatre
défauts ou « sain ».

Quatre défauts à traquer à chaque clôture.

**La description floue.** C'est elle qui décide du déclenchement. Trop vague, le skill ne part jamais
ou part tout le temps. Elle doit lister des formulations concrètes, pas décrire une intention.

**Le doublon.** Deux skills qui se chevauchent se déclenchent au hasard, et le comportement devient
imprévisible. Fusionne, ne garde pas les deux « au cas où ».

**Le skill mort.** Écrit pour un besoin ponctuel, jamais rappelé depuis. Supprime, et dis-le.

**Le secret.** Une clé, un token, un chemin de home, un nom de client. Les skills se publient et se
partagent, un secret dedans sort de la machine. Corrige avant tout le reste.

## Ce que tu ne fais jamais

- Recopier quelque chose du dépôt vers `MEMORY.md`, ou l'inverse. On pointe, on ne duplique pas.
- Commiter `MEMORY.md`, `USER.md` ou `SOUL.md` dans un dépôt de projet. Ils ne lui appartiennent pas.
- Laisser une affirmation que tu sais fausse « pour plus tard ». Il n'y a pas de plus tard, il y a
  un `/new`.
- Supprimer un skill ou un pan de mémoire en silence.
