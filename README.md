# clawd-stack-agent est remplacé par fstack-agent

Ce dépôt n'est plus maintenu. Le skill `clawd-stack-agent` est absorbé par `fstack-agent`, qui reprend son
contenu avec le reste de la convention de contexte.

## Passer à fstack-agent

L'installeur de Hermes a refusé l'ancien paquet le 2026-08-13, son scanner s'arrête sur la
mention de `CLAUDE.md`, et le nouveau porte la même signature. On l'installe donc par un clone,
qui se met à jour par un `git pull`.

Sur Hermes Agent :

```bash
git clone https://github.com/fullya99/fstack-agent.git \
  ~/.hermes/skills/housekeeping/fstack-agent
```

Sur OpenClaw :

```bash
git clone https://github.com/fullya99/fstack-agent.git \
  ~/.openclaw/workspace/skills/fstack-agent
```

Sur Codex :

```bash
git clone https://github.com/fullya99/fstack-agent.git \
  .agents/skills/fstack-agent
```

Pour tous tes dépôts, clone dans `~/.agents/skills/fstack-agent` à la place. Le README de
`github.com/fullya99/fstack-agent` donne le détail.

## Les anciennes versions

Les tags et les releases de ce dépôt restent disponibles, archives `.zip` comprises.
