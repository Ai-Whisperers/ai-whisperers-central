# Contributing to AIW Infrastructure

Thank you for your interest in contributing! This document provides guidelines for contributing to the AI Whisperers infrastructure.

## Code of Conduct

This project follows our [Code of Conduct](https://github.com/Ai-Whisperers/.github/blob/main/CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## How to Contribute

### Report a Bug

1. Check existing issues to avoid duplicates
2. Use the **Bug Report** issue template
3. Include: steps to reproduce, expected vs actual behavior, logs, environment details

### Request a Feature

1. Use the **Feature Request** issue template
2. Describe the problem you are solving, not just the solution

### Submit a Change

1. **Branch:** Create a branch from `master`
   - `feat/` — new features
   - `fix/` — bug fixes
   - `docs/` — documentation changes
   - `refactor/` — code refactoring
   - `chore/` — maintenance tasks
2. **Make Changes:** Keep PRs focused and small
3. **Commit Messages:** Use [Conventional Commits](https://www.conventionalcommits.org/)
   ```
   feat: add health check endpoint
   fix: resolve connection pool leak under load
   docs: update deployment runbook
   chore: bump docker image
   ```
4. **Test:** Run `scripts/health-check.sh` and `scripts/full-test-suite.sh`
5. **Open PR:** Use the pull request template

### Commit Message Format

```
<type>(<scope>): <description>

[optional body]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`

## Security

**Never commit secrets, API keys, or credentials.** All sensitive values go in `.env` files (which are gitignored). Use `.env.template` as the template.

If you find a security vulnerability, see [SECURITY.md](SECURITY.md).

## Development Setup

```bash
git clone https://github.com/Ai-Whisperers/aiw-infra.git
cd aiw-infra
cp .env.template .env        # Fill in your values
./deploy.sh monitoring       # Start monitoring stack
scripts/health-check.sh      # Verify everything is running
```

## Code Style

### Shell Scripts
- Use `#!/bin/bash` shebang
- Use `set -euo pipefail` for robust scripts
- Quote all variable expansions
- Use meaningful variable names

### Docker Stack Files
- Use `version: "3.8"` (or omit for compose v2)
- Always set memory and CPU limits
- Use health checks where possible
- Use named volumes, not bind mounts

### Python (Microservices)
- Follow PEP 8
- Use type hints where practical
- Handle errors explicitly

## Questions?

Open a [Discussion](https://github.com/Ai-Whisperers/aiw-infra/discussions) or an issue.