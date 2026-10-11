# MODE-RELANCE : repartir à froid sans payer cher

> **Le contrat** : après un redémarrage de contexte (`/new` chez Hermes, nouvelle session ailleurs), tu donnes la bonne
> prochaine étape en ne lisant que le bloc de reprise, la carte et les trois dernières entrées du
> journal. Rien de plus sans raison. Une reprise chère annule le bénéfice du redémarrage.

L'intention de l'opérateur, si elle est donnée, passe avant la déduction. Sinon la suite logique
est la « Prochaine étape » du bloc.

## 1. Situer la dernière clôture

Aucun rappel ne se lance seul au démarrage de la session, c'est à toi de regarder. Le dernier
commit et la date de l'entrée du jour en tête du CHANGELOG disent quand la clôture a eu lieu :

```bash
git log --oneline -3 && awk '/^## /{n++} n<=1' CHANGELOG.md | head -3
```

- le commit de clôture est le dernier : le dépôt est dans l'état que la clôture a décrit
- du travail a eu lieu après : le bloc de reprise peut être en retard, l'étape 3 le dira
- aucune clôture visible : le bloc de reprise fait foi

## 2. Lire dans cet ordre, et pas plus

Jamais un pilier en entier.

```bash
awk '/^## /{n++} n<=1' TODOS.md      # le bloc de reprise, rien d'autre de TODOS.md
grep -n '^## ' CODEMAP.md            # le plan de la carte, puis la seule section utile
awk '/^## /{n++} n<=3' CHANGELOG.md  # les trois dernières entrées
```

`CLAUDE.md` est déjà chargé chez Claude Code, ailleurs lis-le. Si la tâche touche une zone, lis la
carte de cette zone. Ne lis les fiches `docs/` que des modules concernés par la tâche à venir, et
l'ADR correspondant si tu t'apprêtes à revenir sur un choix tranché.

Si le journal n'est pas en `## AAAA-MM-JJ`, le bloc `contexte:convention` déclare son format dans
`journal:`, voir `references/CONFIG-PROJET.md`.

**Ne lis jamais `archives/`.** C'est du faux ou du froid par construction. Pour chercher pourquoi
une chose est faite comme ça :

```bash
bash "$SKILL/scripts/ctx-archeo.sh" <motif>     # provenance avant extrait, sortie bornée
```

Jamais un `grep` nu : il rend une ligne sans son en-tête et tu prends du froid pour du courant.

**Observable** : tu peux citer la prochaine étape du bloc, et tu as lu moins de trois fichiers
entiers.

## 3. Vérifier le terrain

Le bloc de reprise porte une ligne `Vérifier le terrain` avec une commande copiable. Lance-la
telle quelle, puis confronte le dépôt à la doc :

```bash
git log --oneline -10 && git status -s
```

Sans cette ligne, ces deux commandes sont le minimum. Une divergence se signale tout de suite : un
bloc qui ne colle plus au dépôt est le symptôme d'une clôture bâclée, et ça se corrige avant de
coder. Si `bash "$SKILL/scripts/ctx-audit.sh" --budget` est disponible, un pilier qui déborde se
signale aussi.

**Observable** : la commande a tourné, sa sortie est conforme au bloc ou l'écart est nommé.

## 4. Restituer

Dix lignes au plus : où on en est, ce qui est en cours, la prochaine étape, les pièges de la
rubrique « À savoir avant de toucher », les incohérences trouvées. Puis demande si on part sur la
prochaine étape, ou sur l'intention donnée.

## Le prompt de redémarrage

Quand l'opérateur veut préparer la session suivante (« prépare le redémarrage », « prompt pour
après le `/clear` »), ton seul livrable est un prompt à coller dans la session neuve. Tu ne
modifies aucun fichier. Si le bloc de reprise est périmé, dis-le et propose une clôture d'abord,
car le prompt ne vaut que ce que vaut le dépôt.

Le prompt tient dans un seul bloc `text`, rien après lui. Quatre sections, chaque fait venant de
l'état réel lu, jamais inventé :

1. **Mission** : 1 à 3 lignes, quoi et pourquoi, avec les chemins réels concernés.
2. **Orientation** : l'ordre de lecture de l'étape 2, avec la zone concernée nommée.
3. **Règles** : un renvoi vers `CLAUDE.md` et les règles du projet, pas leur copie. Les contraintes
   propres à la tâche (accès, ressource externe fragile) s'ajoutent, une ligne chacune.
4. **Démarrage** : la ligne `Vérifier le terrain` du bloc, puis la prochaine étape, puis « si une
   hypothèse est ambiguë, demande avant d'agir ».

Au-dessus du bloc, une ligne : le niveau visé et la consigne « colle ce qui suit après le
redémarrage de contexte ».

**Observable** : chaque chemin et chaque commande du prompt existe dans le dépôt.
