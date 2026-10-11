# RESOLUTION : pourquoi la boucle `$SKILL` cherche là, dans cet ordre

Lis cette page quand la boucle rend vide alors que le skill est installé sur la machine, ou
quand elle résout une version qui n'est pas la bonne.

## L'ordre des candidats

L'ordre est voulu. Les installations d'agent permanent d'abord, Hermes dans `~/.hermes/skills/`
avec ou sans dossier de catégorie, puis OpenClaw, puis la portée projet de Codex et d'OpenClaw,
puis la portée utilisateur de Codex.

## Hermes

Le scan de `~/.hermes/skills/` est récursif, le dossier de catégorie est du rangement. Un `find`
borné à quatre niveaux couvre `~/.hermes/skills/<nom>/` et `~/.hermes/skills/<categorie>/<nom>/`.

## OpenClaw

Le workspace est `~/.openclaw/workspace` par défaut, mais il se configure par
`agents.defaults.workspace` dans `~/.openclaw/openclaw.json`. Il est le répertoire de travail de
l'agent, donc `skills/<nom>/` résout depuis le répertoire courant quel que soit son emplacement
réel. C'est le candidat relatif de la boucle. Un `find` sur `~/.openclaw` couvre les installations
à l'emplacement par défaut.

## Les deux répertoires utilisateur de Codex

Codex a deux répertoires de portée utilisateur, `~/.codex/skills/` où son installeur dépose, et
`~/.agents/skills/` du standard ouvert. Les deux sont scannés. Le premier passe avant parce qu'il
porte la version que l'utilisateur a réellement installée, quand l'autre peut garder une copie
posée à la main et devenue vieille.

## La remontée des ancêtres

Codex n'a pas d'équivalent d'une variable qui désigne le dossier du skill, cette boucle est son
seul mécanisme de résolution. Il remonte l'arborescence pour trouver `.agents/skills/`, et
`$ANCETRES` fait la même chose avant la boucle, en testant chaque ancêtre du répertoire courant.
Un skill posé à la racine d'un dépôt pendant qu'on travaille dans un sous-dossier est donc trouvé.

Le test porte sur la présence de `scripts/ctx-audit.sh`, ce qui écarte au passage les répertoires
homonymes.

## Symptôme, cause, geste

| Symptôme | Cause probable | Ce qu'on fait |
|---|---|---|
| Boucle vide chez Hermes | le skill est posé ailleurs que sous `~/.hermes/skills/` | on le déplace ou on le clone là |
| Boucle vide chez OpenClaw | le workspace a été déplacé et le répertoire courant n'est pas le workspace | on se place dans le workspace, ou on regarde `agents.defaults.workspace` |
| Vieille version résolue | une copie plus ancienne passe avant | on met à jour par `git pull` dans le dossier trouvé, ou on retire la copie |
| Codex ne trouve rien | le skill est dans `~/.claude/skills` et pas dans `~/.agents/skills` | on copie |
