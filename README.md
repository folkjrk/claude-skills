# Claude Skills

Personal Claude Code skills for reuse across machines.

## Skills

| Skill | Description |
|-------|-------------|
| `trivy-cve-scan` | Check Dockerfile (create if missing), build Docker image, run Trivy CVE scan |
| `frontend` | React 18+/19 + TypeScript best practices guide |
| `code-audit` | Staff Engineer's Audit Framework (V2) — 5-pillar React/TS code review |
| `feature-modularization-protocol` | UFMP v3 — modularize complex React/TS features into scalable structures |
| `game-character-64` | Generate 64×64 pixel-art character spritesheets (8-direction, idle/walk/attack) for 2D games |
| `inital project` | Scaffold a new React 19 + React Router v7 + UFMP project with `run.sh` and `CLAUDE.md` |

## Install on a new machine

```bash
# Clone directly into Claude skills directory
git clone https://github.com/folkjrk/claude-skills.git ~/.claude/skills
```

## Update skills on current machine

```bash
cd ~/.claude/skills
git pull
```

## Sync changes back to GitHub

```bash
cd ~/.claude/skills
git add .
git commit -m "update skills"
git push
```

## Usage in Claude Code

```
/trivy-cve-scan
/frontend
```
