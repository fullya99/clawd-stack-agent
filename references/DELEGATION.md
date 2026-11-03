# Déléguer par rôles

La session principale orchestre. Elle garde le cadrage, l'arbitrage, la décision irréversible et
la validation. Le reste se confie à un rôle, lecture comprise. Valable pour tout projet et tout
langage.

Un rôle n'est pas un agent installé. C'est un travail avec son critère de fin. Quand la plateforme
a des sous-agents, tu le confies à l'un d'eux, avec le brief plus bas. Quand elle n'en a pas, tu le
tiens toi-même comme une étape à part, et tu vérifies son critère avant de passer à la suivante.
Hermes expose `delegate_task`, OpenClaw n'a pas d'outil de délégation documenté officiellement à ce
jour, Codex dépend de sa version. Regarde ce que ta session offre avant de choisir.

## Les rôles

| Rôle | Poids du modèle | Outils | Pour |
|---|---|---|---|
| `explorateur` | léger | lecture et Bash | trouver, lire, inventorier, compter, résumer un fichier borné |
| `controleur` | léger | lecture et Bash | lancer tests, linters et scripts de contrôle, rendre la sortie brute |
| `executant` | intermédiaire | tous | geste mécanique déjà décidé : renommage, patch fourni, régénération |
| `developpeur` | intermédiaire | tous | implémenter un changement cadré, avec ses tests et sa doc |
| `chercheur` | intermédiaire | web, lecture et outils de recherche de la session | information externe, sourcée et datée |
| `expert` | le plus capable disponible | tous | cause racine inconnue, migration, sécurité, code délicat |
| `relecteur` | le plus capable disponible | sans écriture, Bash pour lancer des contrôles seulement | relecture adversariale d'un diff contre ses critères, toujours neuf |

Le poids du modèle est une intention. Le choix du modèle appartient à la plateforme, ces agents
routent vers plusieurs fournisseurs, et le skill n'en exige aucun.

## Choisir

Le rôle le plus bas qui tient le critère de fin. Un échec repart une fois au cran du dessus, puis
l'orchestrateur reprend la main. Un modèle plus lourd en sous-agent se demande explicitement, il
n'est jamais le défaut.

Une sortie d'`explorateur` ou de `controleur` se recoupe avant d'agir : on exige des chemins et des
chiffres, on relance un `grep` ou un `wc` sur ce qui engage la suite. Un rôle bon marché qui
enchaîne les tours sur une tâche à plusieurs étapes finit par coûter plus qu'un cran au-dessus :
le poids léger pour un contrat fermé (trouver, compter, lancer), pas pour une enquête.

## Le brief

Un sous-agent démarre à contexte zéro. Il ne voit ni la conversation, ni le plan, ni les décisions
déjà prises. Tout ce qu'il doit savoir passe dans le brief, en quatre éléments, dans cet ordre :

1. La spec : ce qu'on veut, en quelques lignes.
2. Les chemins exacts : fichiers à lire, fichiers à écrire.
3. Le critère de fin : une commande qui passe, ou un fait observable.
4. La consigne « vise court ».

Un fait que l'orchestrateur a mesuré passe dans le brief avec sa commande et sa date. Sans elles,
il s'écrit « rapporté » et le rôle le revérifie avant de bâtir dessus.

**Le paquet du relecteur.** Un `git diff` nu ne montre ni les fichiers neufs ni l'état de l'index.
L'orchestrateur prépare le paquet hors du dépôt et le donne par son chemin :

```bash
P=<dossier temporaire>/revue; mkdir -p "$P"
git status --porcelain > "$P/etat.txt"
git diff HEAD > "$P/diff.patch"
# diff --no-index rend 1 des qu'il y a une difference, donc xargs rend 123 sur un paquet correct :
# ce code ne juge rien, on compte les fichiers du paquet contre etat.txt.
git ls-files --others --exclude-standard -z | xargs -0 -r -I{} git diff --no-index /dev/null {} >> "$P/diff.patch"
git status --porcelain | cksum > "$P/empreinte.txt"   # l'arbre ne bouge plus pendant la revue
split -b 60000 "$P/diff.patch" "$P/tranche-"           # une lecture plafonne vers 25 000 tokens
```

Le brief nomme les invariants du projet à vérifier en premier (secrets, écritures distantes,
codes de retour, ce que `AGENTS.md` ou `CLAUDE.md` interdit), avant la correction générale. À la
fin, l'empreinte se recalcule : si elle a changé, la revue a porté sur un autre arbre et se rejoue.

Le rapport revient en trois lignes, puis le détail demandé :

```
Fait : <ce qui est terminé>
Reste : <ce qui n'est pas fait>
Surpris : <ce que le brief ne prévoyait pas>
```

## Les limites

- Jamais deux agents sur les mêmes fichiers.
- Cinq agents en parallèle au plus.
- Un agent ne lance pas d'agent.
- Un agent ne commite pas et ne pousse pas.
- Au-delà d'environ 200 appels d'outils, un agent s'arrête avec un point d'étape.
- Un agent qui écrit passe par les outils d'édition de la plateforme, jamais par un heredoc ou un
  `sed -i` en shell.

## Sans sous-agents

La doctrine devient un découpage en étapes. Chaque étape a son critère de fin, vérifié avant de
passer à la suivante, et tu tiens les rôles l'un après l'autre. La relecture est la seule étape qui
ne se rejoue pas dans le même contexte : fais-la dans une session neuve si la plateforme le permet,
sinon relis le diff à froid, après avoir fermé ce que tu en sais, et cherche ce qui casse.

## Régler l'effort

Le réglage du modèle et de l'effort de la session principale dépend de la plateforme. Un effort
élevé sur la session qui orchestre et un modèle plus léger sur les rôles mécaniques est la bonne
forme, mais le skill ne le règle pas pour toi. Cherche le réglage dans la configuration de ta
plateforme, et ne retiens aucun identifiant de modèle précis dans un fichier du projet : il se
périme.
