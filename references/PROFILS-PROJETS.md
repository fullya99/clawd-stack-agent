# PROFILS-PROJETS : adapter la convention à un projet

> La convention est la même partout, son remplissage change. Un profil dit ce qu'INIT pose et ce
> que le bloc `contexte:convention` doit déclarer. La taille se mesure à part, elle ne dépend pas
> du profil.

## Détecter le profil

Sans bloc dans `CODEMAP.md`, INIT déduit le profil des fichiers présents, prend le dominant et
note les autres dans le bloc. En cas de doute, il demande.

| Indices | Profil |
|---|---|
| `package.json` avec framework web, `manage.py`, `main.go`, `Program.cs` | app |
| `pyproject.toml` sans point d'entrée, `Cargo.toml` en lib, un `index.ts` exporté | lib |
| `terraform/`, `ansible/`, `k8s/`, `docker-compose.yml` | infra |
| `notebooks/`, `dvc.yaml`, `train.py` | data |
| `content/`, `posts/`, majorité de `.md` | contenu |
| `packages/`, `pnpm-workspace.yaml`, `turbo.json`, `go.work` | monorepo |
| `.gitmodules` avec des enfants équipés | parent à sous-modules |
| `SKILL.md`, `plugin.json`, `commands/` | outillage-agent |
| aucun code, documents et suivi | non technique |

## La taille

Comptée en fichiers, hors dépendances, builds et `archives/`. L'audit la mesure, `ctx-init.sh` ne l'écrit pas.
Seule `taille-forcee:` existe, posée par la migration quand l'opérateur garde une valeur qui
diffère de la mesure (voir `CONFIG-PROJET.md`).

| Taille | Fichiers | INIT pose |
|---|---|---|
| petite | moins de 150 | un seul niveau, aucune zone |
| moyenne | 150 à 600 | des zones là où la carte racine déborde |
| grande | plus de 600 | des zones d'emblée, la carte racine n'est qu'un index |

## Profils de nature

**Projet neuf.** Aucun code, aucun historique. INIT pose les gabarits courts et le bloc, rien
d'autre. Les cartes se remplissent au fil des sessions, pas par anticipation.

**Existant documenté autrement.** README, wiki, dossier `memory-bank`. INIT greffe les trois piliers à
côté et fait pointer le bloc vers l'existant. Rien n'est dissous, ce qui est déjà en place reste
tant que l'opérateur n'a pas tranché.

**Reprise d'un projet inconnu.** INIT cartographie depuis le code et l'historique git. Il
n'écrit que ce qu'une commande a confirmé, le reste part en questions dans `TODOS.md`.

**App.** Module : une couche ou un domaine. Le bloc déclare la commande de démarrage et celle des
tests. La carte insiste sur les points d'entrée, le flux d'une requête et les variables d'environnement.

**Lib.** Module : un sous-ensemble de l'API publique. Le journal est un livrable public, format
Keep a Changelog, ce que la clé `journal:` déclare. La carte donne la surface exportée.

**Infra.** Module : un composant déployé. L'état vit hors du dépôt, donc le bloc déclare la
source d'autorité à interroger (état du provisioning, console). `docs/ops/` est le cœur, et
chaque entrée de journal porte son retour arrière. Jamais une valeur de secret, seulement son
emplacement.

**Data.** Module : une étape de pipeline. La carte donne le lignage et l'emplacement des
artefacts. Tout chiffre cité porte la date de son run.

**Contenu.** Module : une rubrique ou un canal. Le ton et le positionnement vont dans
`CLAUDE.md`, les angles abandonnés dans `archives/`.

**Monorepo.** Chaque package équipé garde son kit, la racine pointe sans recopier. Le bloc liste
les packages et les zones. Voir `ZONES.md`.

**Parent à sous-modules et instances qui partagent un savoir.** INIT ne touche que le parent et
liste les enfants. Voir `MULTI-DEPOTS.md`.

**Outillage d'agent.** Module : un skill, une commande ou un script. Le projet applique sa propre
convention. La vérification porte sur les chemins cités depuis le skill et sur les scripts
exécutables.

**Projet en anglais.** Le bloc déclare `langue: en`, INIT pose les gabarits avec des en-têtes
anglais et l'audit ne cherche pas les français.

**Projet hors code.** Module : un chantier. `docs/decisions/` porte l'essentiel, chaque arbitrage
et la position des parties prenantes valent un ADR. Le journal tient lieu de compte rendu.

## Adapter sans casser

Trois libertés, toutes déclarées dans le bloc : renommer (les rôles comptent, pas les noms),
fusionner sur un très petit projet (la fusion se défait dès qu'une section dépasse une page),
étendre par un pilier de plus s'il répond à une question qu'aucun autre ne couvre.

Jamais adapté, quel que soit le profil : le bloc d'état à la reprise, l'archivage au lieu de la
suppression, l'interdiction de lire `archives/` comme source de vérité, aucune affirmation
connue fausse après une clôture.

Aucun outil externe n'est requis. Une recherche web ou un outil de projet accélère une
vérification, une étape de clôture n'échoue jamais faute d'eux.
