# Exécution du plan

Il n'y a pas de session neuve à ouvrir ni de bloc à coller après un redémarrage de contexte. Le plan s'exécute
directement, à la suite de son écriture ou dans une reprise plus tard, par une équipe d'agents ou
tout seul selon ce que la plateforme permet.

## La section Reprise du plan

Le plan porte une section « Reprise », à la place du prompt d'exécution de la variante Claude
Code. Elle contient ce qu'un exécutant doit savoir sans avoir suivi les phases précédentes : le
chemin du plan lui-même désigné comme source de vérité, les décisions verrouillées restatées en
clair, ce qu'on ne touche pas, les invariants, la composition de l'équipe et le rôle de chacun, et
l'étape où on en est.

Cette section ne se fige pas à l'écriture. Elle se met à jour au fil de l'exécution : l'étape en
cours avance, un état surprenant s'y note, une décision qui a bougé s'y corrige. Un exécutant qui
reprend le plan trois jours plus tard la lit en premier et sait où reprendre sans relire tout
l'historique.

## L'équipe

Les rôles et leur graduation sont dans `references/DELEGATION.md`. Trois à cinq agents, pas plus. Au-delà, le pilote passe plus de temps à coordonner qu'à avancer.

- **Le pilote.** Séquence les lots, ouvre les portes de vérification, ne code pas lui-même les
  gros lots pour garder son attention sur l'ordonnancement.
- **Les implémenteurs.** Un par lot indépendant, chacun démarre sans rien savoir du reste.
- **Le relecteur.** Contexte frais, il ne voit que le diff produit et les critères de la tâche
  concernée. Son mandat s'arrête à ce qui casse la correction du code ou une exigence écrite dans
  le plan. Le style et la préférence personnelle restent hors de son mandat, sinon il en trouve
  toujours et l'exécution part en sur-ingénierie pour satisfaire des remarques qui ne comptaient
  pas.

## Chez Hermes, la délégation

L'équipe se demande par `delegate_task`, avec `goal`, `context`, `max_iterations` (50 par défaut),
`role` (`leaf` ou `orchestrator`) et `background`. Trois sous-agents partent en parallèle par
défaut, réglable dans la configuration.

Le piège numéro un de cette plateforme : **le sous-agent démarre à contexte zéro.** Il ne voit ni
la conversation qui l'a fait naître, ni le plan par défaut, ni les décisions déjà prises. Tout ce
qu'il doit savoir passe par `goal` et `context`, sans exception : le chemin du plan, les décisions
verrouillées qui s'appliquent à son lot, ce qu'il ne doit pas toucher et le critère qui dit que son
lot est fini. Un `delegate_task` qui se contente d'un `goal` court et laisse le reste à
l'implicite envoie un agent travailler à l'aveugle.

## Chez OpenClaw, la dégradation en séquentiel

Aucun outil de délégation officiel n'est documenté à ce jour. C'est un état de la doc à la date de
cette recherche, pas une propriété qui restera vraie indéfiniment. Tant que rien d'officiel
n'existe, l'exécution se fait en séquentiel : une tâche après l'autre, dans l'ordre du plan, avec
les mêmes portes de vérification à chaque étape. Un seul agent tient alors les rôles de pilote et
d'implémenteur, le relecteur reste une passe distincte, en contexte frais si la plateforme le
permet.

## Aucun modèle exigé

Ces agents sont multi-fournisseurs, le routage du modèle appartient à la plateforme, pas au plan.
La consigne « avant de conclure, vérifie que [critère] » profite à la plupart des modèles avant de
rendre un résultat. Un modèle qui se vérifie déjà seul n'en a pas besoin, donc elle s'écrit une
fois par étape, elle ne se répète pas à chaque ligne du plan.

## La règle de parallélisme

Deux lots qui touchent les mêmes fichiers ne partent jamais dans le même tour, que l'exécution
soit en parallèle chez Hermes ou en séquentiel ailleurs. Le découpage tranché dans le plan dit déjà
lesquels, l'exécution le respecte sans le rediscuter.

## Un exemple

Cas simple, un plan qui ajoute un champ `archived` à un modèle et l'expose dans une route. Le lot
migration part chez Hermes en `delegate_task` :

```
goal: Ajouter le champ archived au modèle Task, migration et modèle seuls. La route qui
  l'expose fait l'objet d'un autre lot, ne la touche pas.

context: Lis en entier plans/ajout-champ-archived.md avant de commencer, c'est la source de
  vérité. Décision verrouillée : le champ s'appelle `archived`, booléen, défaut false, pas de
  champ archivedAt. Ne touche pas à la table users ni à la route d'authentification. Le test
  existant tests/models/task.test.js doit continuer à passer. Avant de conclure, vérifie que la
  migration s'applique sur une base vide et que ce test passe. Termine par trois lignes : ce qui
  est fait, ce qui reste, ce qui a surpris.

max_iterations: 50
role: leaf
```

Le lot route, qui consomme le champ ajouté, attend la fin de ce premier lot avant de partir,
puisqu'il en dépend.
