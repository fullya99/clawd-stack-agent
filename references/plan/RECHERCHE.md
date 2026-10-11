# Recherche, quand et comment

## Quand chercher, quand ne pas chercher

La surface externe décide. Une refonte interne pure, un correctif dans du code qu'on possède, un
renommage : pas de recherche, le plan l'écrit noir sur blanc plutôt que de se remplir de notes
hors sujet.

Une lib externe, l'API d'un fournisseur, une version récente, un comportement susceptible d'avoir
bougé, un choix technologique à trancher : recherche.

## L'ordre des sources

1. La documentation officielle de l'outil ou du service, à la version visée. C'est la source de
   vérité et elle évite l'API inventée.
2. La recherche web native de la plateforme, pour les faits datés, les retours de terrain et les
   pages à lire en entier.
3. Les connecteurs MCP de recherche, s'il y en a dans la session. Rien n'est installé par défaut.
   Observe le nom réel de l'outil dans la liste des outils disponibles et utilise-le tel quel,
   ne le code jamais en dur.

### Chez Hermes

`web_search` et `web_extract` sont natifs, dans le toolset `web`, disponibles sans rien installer.
Le client MCP est natif aussi, en stdio et en HTTP/SSE, avec un catalogue de serveurs désactivés
par défaut. `hermes mcp install <nom>` installe celui qui manque, quand la tâche le justifie
vraiment.

Le préfixe d'un outil MCP diverge entre deux pages de la doc officielle : une page donne
`mcp__<serveur>__<outil>`, une autre `mcp_<serveur>_<outil>`. Ne suppose pas laquelle est vraie
sur la machine en cours.

### Chez OpenClaw

La recherche web native n'existe que lorsque le modèle sous-jacent est Claude. Sur un autre
modèle, rien n'est garanti par défaut. Le MCP est pris en charge, un serveur peut s'ajouter si le
besoin le justifie.

## La dégradation

Aucun connecteur n'est un prérequis. Un agent sans serveur MCP suit ce skill avec sa seule
recherche web native, `web_search`, WebSearch ou autre selon la plateforme. Le plan écrit
« recherche native » dans ce cas et note ce qui a été cherché, avec quel outil. Il ne bloque
jamais parce qu'un connecteur manque.

## Le découpage en axes

Un axe par chercheur. Trois à cinq axes suffisent, rarement plus. Axes types :

- l'outil ou la lib visée et sa version courante
- l'état de l'art de la pratique
- les pièges et retours de terrain
- la contrainte réglementaire ou de plateforme, quand il y en a une

Chez Hermes, un axe part en `delegate_task`, trois axes en parallèle par défaut, réglable dans la
config sous `delegation.max_concurrent_children`. Ailleurs, faute d'équivalent documenté, les axes
s'enchaînent en série.

Ne donne jamais deux axes au même chercheur. Un chercheur qui doit couvrir deux sujets en couvre
un bien et l'autre mal, et rien ne dit lequel.

## Le contrat de sortie d'un chercheur

Des notes brutes, pas un rapport mis en forme. Chaque affirmation part avec son lien et sa date.
Une source de plus de six mois se marque comme peut-être périmée. Ce qui est contesté entre deux
sources se signale comme tel plutôt que d'être tranché à la place de l'opérateur. Rien de trouvé
sur un point s'écrit « non trouvé », jamais une supposition habillée en fait.

Pas d'introduction, pas de conclusion. Le chercheur qui synthétise avant de rendre perd la
traçabilité que ces notes existent pour donner.

## Ce qui entre dans le plan

Seulement ce qui a façonné une décision. Une note de recherche que le plan n'utilise pas ne s'y
recopie pas, elle reste dans les notes du chercheur. Un plan encombré de recherche non exploitée
est plus dur à relire qu'un plan qui va droit aux décisions qu'elle a produites.
