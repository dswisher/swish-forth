# AGENTS.md

## Ground rules

Agents should never issue `git` commands that alter the state of the local or remote repositories - no `git commit`, `git pull` or `git push`.
Informational commands like `git log` or `git diff` are fine.

