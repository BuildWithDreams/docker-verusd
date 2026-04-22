# Skills

This repo contains **two forms of documentation** that should always stay in sync:

## `SKILL.md` — Hermes Agent Skill

`SKILL.md` in the repo root is the canonical skill document for the Hermes AI agent framework. It is:

- The **source of truth** for the agent's knowledge of this project
- **Embedded in the repo** so documentation and code cannot drift apart
- Referenced from `~/.hermes/skills/blockchain/docker-verusd/` as a symlink or local skill

### Skill Architecture

```
BuildWithDreams/docker-verusd/
├── SKILL.md          ← canonical skill (here, in the repo)
└── ...

~/.hermes/skills/
└── blockchain/
    └── docker-verusd/  → symlink or local copy → ~/docker-verusd/SKILL.md
```

**Why embedded in the repo and not in the skills hub?**
- The skill documents the code; keeping them together prevents drift
- Changes to Docker compose, network topology, or CLI behavior can be updated alongside the code
- A single clone gives the agent everything it needs
- Auditable via git history — who changed what and why
- Skills hub publishing happens only after workflow is verified

**Workflow:** code first → skill update after verification → publish to hub when stable

## `README.md` — Human Documentation

The human-facing getting-started guide lives in `README.md` and should contain only what a human operator needs: setup steps, commands, chain configurations.

## Keeping Them in Sync

When making changes to the project:
1. Update the code/configuration
2. Update `SKILL.md` with the change
3. Update `README.md` if the human-facing steps changed
4. Commit together — they form one logical change
