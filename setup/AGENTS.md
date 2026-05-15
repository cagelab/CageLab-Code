## Scope

Rules for automated changes and contributions in this repo, focusing on:

- zsh scripts (bootstrap/setup tooling)
- Ansible (playbooks/roles)

## Install

- [bootstrap.sh](bootstrap.sh) — for initial bootstrap of tools and packages necessary for CageLab: https://github.com/cagelab/CageLab 
- [makelinks.sh](makelinks.sh) — a script to ensure scripts and services are symlinked into the correct locations. Should be run every time any files change.

## zsh script rules (`*.sh`, `*.zsh`)

- Use zsh explicitly:

  ```zsh
  #!/usr/bin/env zsh
  ```

- Prefer “strict mode” behavior:

  ```zsh
  set -euo pipefail
  setopt PIPE_FAIL
  ```

  Note: zsh uses `setopt PIPE_FAIL`; keep whichever is appropriate for your
  target shells, but don’t silently ignore pipeline failures.

- Use tabs for indentation.
- Always quote variables unless you explicitly want word-splitting/globbing.
- Prefer arrays for lists; avoid `eval`.
- Use functions for logical units; keep scripts idempotent when possible.
- For external commands:
  - Check dependencies (`command -v foo >/dev/null`) and fail with a helpful
    message.
  - Prefer non-interactive flags; avoid prompting unless required.
- Shell linting:
  - Prefer `shellcheck` where applicable (note: zsh support is partial).
  - Keep scripts compatible with the repo’s target OSes.

## Ansible rules

- YAML indentation: **2 spaces**, never tabs.
- Prefer roles over monolithic playbooks as complexity grows.
- Idempotence:
  - Avoid `shell`/`command` unless necessary.
  - When using `command`/`shell`, set `creates:`/`removes:` or `changed_when:`
    and `failed_when:` appropriately.
- Use fully qualified collection names where practical (e.g.
  `ansible.builtin.copy`).
- Prefer templates for config files; avoid inline multi-line blobs unless small.
- Secrets:
  - Never commit secrets.
  - Use Ansible Vault or external secret providers.
- Linting/tests:
  - Run `ansible-lint` on changes.
  - Keep tasks readable: small tasks, clear names, minimal conditionals.

## Repository-specific notes

- If you introduce YAML, ensure no tabs exist (validators may reject).
- Prefer minimal, composable scripts over large one-offs.
- When in doubt, match existing patterns in this repo.
