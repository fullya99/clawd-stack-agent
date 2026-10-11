# Ta mémoire, et pourquoi tu n'y écris pas

Chargé quand une ligne de ta mémoire touche au sujet audité. Vérifié le 2026-08-23 sur la
documentation Hermes Agent et OpenClaw.

## Les trois étages, et à qui appartient quoi

| Étage | Hermes | OpenClaw | Qui l'écrit |
|---|---|---|---|
| identité | `~/.hermes/SOUL.md` | `<workspace>/SOUL.md` | l'opérateur, une fois |
| profil | `~/.hermes/memories/USER.md` | `<workspace>/USER.md` | toi, sur ce qu'il te dit de lui |
| mémoire | `~/.hermes/memories/MEMORY.md` | `<workspace>/MEMORY.md` | toi, en continu |
| journal | néant | `<workspace>/memory/AAAA-MM-JJ.md` | toi, au fil de la journée |
| projet | `AGENTS.md`, `CLAUDE.md`, `.hermes.md` | `AGENTS.md` du workspace | l'équipe du projet |

La dernière ligne est la seule que ce skill modifie. Les quatre autres se lisent.

Chez Hermes, la mémoire est réinjectée dans le prompt système **à chaque tour**, pas seulement au
début de session. Une ligne fausse là-dedans coûte donc plus cher qu'une ligne fausse dans un
fichier de projet. C'est justement pour ça qu'on ne la corrige pas à l'aveugle.

## Pourquoi tu n'y écris pas

**Le juge et la partie.** Un audit qui corrige ta propre mémoire n'a plus de juge extérieur. Tu
serais l'auteur de la règle, celui qui la vérifie et celui qui la réécrit. Le rapport ne veut plus
rien dire, et l'opérateur n'a plus rien à approuver.

**Le vecteur d'attaque.** L'injection d'instructions dans la mémoire d'un agent est le premier cas
de skill malveillant listé par l'OWASP dans son Top 10 des skills agentiques. Les scanners
d'installation classent cette écriture comme critique, et le verdict n'est pas contournable. Ce
n'est pas une prudence excessive de leur part : l'audit ToxicSkills de Snyk, en février 2026, a
trouvé 13,4 % de défauts critiques sur 3 984 skills publics scannés.

**La conséquence pour toi.** Un skill qui écrirait dans `MEMORY.md` ne s'installerait officiellement
nulle part. Celui-ci n'y écrit pas, et il n'explique à personne comment le faire.

## Ce que tu fais à la place

Tu compares, tu montres, tu laisses trancher.

```
Ta mémoire dit    : « le déploiement passe par le script deploy.sh »
Le dépôt dit      : deploy.sh n'existe plus, remplacé par .github/workflows/deploy.yml
Preuve            : find . -name deploy.sh → 0
```

Trois formes de contradiction valent le signalement.

- **Ta mémoire contredit une ligne du dépôt.** Tu montres les deux et leur date. Souvent la mémoire
  est plus récente, et c'est le dépôt qu'il faut corriger.
- **Ta mémoire redit ce que le dépôt dit déjà.** Doublon. Deux copies divergent toujours. Tu
  proposes de garder celle du dépôt, parce qu'elle est versionnée et relue.
- **Ta mémoire porte une règle de projet.** Elle n'est pas à sa place : elle s'appliquerait à tous
  les projets. Tu proposes de la déplacer dans le fichier d'instructions du dépôt.

Dans les trois cas, la sortie est une ligne de rapport et une question. Jamais une écriture.

## La limite de taille, et ce qu'elle ne fait pas

Hermes fait respecter une limite dure d'environ 2200 caractères sur `MEMORY.md`, en refusant les
ajouts au-delà. C'est un plafond, pas un ménage : rien ne relit la mémoire pour en retirer ce qui
est devenu faux.

Autrement dit, la mémoire se remplit puis se bloque, et ce qui y est faux y reste. Signaler les
contradictions est donc utile même quand le plafond n'est pas atteint, et surtout quand il l'est.

## La frontière de session

Un `/new` chez Hermes, une session neuve chez OpenClaw, et le contexte de conversation disparaît.
La mémoire sur disque, elle, ne bouge pas. Seul un `/quit --delete` supprime l'historique.

Pour ce skill, ça veut dire une chose pratique : ton tableau de preuves vit dans la conversation, et
il ne survit pas. Un audit se fait d'un bloc. S'il doit s'interrompre, écris le rapport dans un
fichier du projet avant de t'arrêter, et pas dans ta mémoire.
