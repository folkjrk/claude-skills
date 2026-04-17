# Claude Skills

Personal Claude Code skills for reuse across machines.

## Skills

| Skill | Description |
|-------|-------------|
| `trivy-cve-scan` | Check Dockerfile (create if missing), build Docker image, run Trivy CVE scan |
| `frontend` | React 18+/19 + TypeScript best practices guide |

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
