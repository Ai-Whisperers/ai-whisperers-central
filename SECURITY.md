# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |

## Reporting a Vulnerability

**Do NOT report security vulnerabilities through public GitHub issues.**

Instead:
- Use [GitHub Security Advisories](https://github.com/Ai-Whisperers/aiw-infra/security/advisories/new) to report privately
- Or contact the team lead directly

We will:
1. Acknowledge receipt within 48 hours
2. Provide an estimated timeline for a fix within 7 days
3. Notify you when the fix is released

## Security Measures

This project uses:
- **`.env` gitignore** — All secrets in environment files, never committed
- **`.env.template`** — Template file with placeholder values only
- **Docker secrets** — Sensitive values passed via environment, not hardcoded
- **LiteLLM master key** — Single gateway key for all AI model access

## Responsible Disclosure

- Give us reasonable time to fix before public disclosure
- Do not access or modify other users data
- Do not degrade service quality
