---
name: create-repo-governance-docs
description: "Please generate standard repository governance documents (SECURITY.md, CODE_OF_CONDUCT.md, SUPPORT.md)"
agent: cursor-agent
tools:
  - search/codebase
  - fileSystem
argument-hint: "Repository root path and which docs to generate (all, security, conduct, support)"
category: documentation
tags: documentation, governance, security, code-of-conduct, support, company-policy
rules:
  - .cursor/rules/prompts/prompt-creation-rule.mdc
  - .cursor/rules/documentation/agent-application-rule.mdc
---

# Create Repository Governance Documents

Please generate the standard governance files that every company repository should have alongside its README and CONTRIBUTING guide.

**Pattern**: Repository Governance Bundle ⭐⭐⭐⭐
**Effectiveness**: Establishes professional standards and clear escalation paths
**Use When**: Setting up a new repository, or existing repos lack governance docs

---

## Purpose

Beyond README and CONTRIBUTING, mature repositories need governance documents that:
- **SECURITY.md** -- Tell people how to report vulnerabilities (not in public issues!)
- **CODE_OF_CONDUCT.md** -- Set behavioral expectations for the team
- **SUPPORT.md** -- Redirect questions to the right channels instead of cluttering issues

These documents are **company policy** and should be present in every repository.

---

## Required Context

- **Repository name**: The repo these docs are for (e.g., `eneve.domain`)
- **Organization/Company name**: e.g., Energy21
- **Security contact**: Email or process for vulnerability reports (e.g., `security@energy21.nl`)
- **Support channels**: Teams channel, email, internal docs, ticketing system

### Optional Context

- **Compliance requirements**: SOC2, ISO 27001, GDPR, etc.
- **SLA expectations**: Response times for security reports
- **Escalation path**: Who to escalate to for different issue types
- **Existing policies**: Links to company-wide policy documents (intranet, SharePoint)
- **Scope**: Generate all docs (`all`) or specific ones (`security`, `conduct`, `support`)

---

## Reasoning Process (for AI Agent)

Before generating governance documents, the AI should:

1. **Understand the Repository**: Read the existing README, CONTRIBUTING, and any existing governance docs to understand the project's context, audience, and maturity
2. **Check for Existing Files**: Verify whether SECURITY.md, CODE_OF_CONDUCT.md, or SUPPORT.md already exist -- do not overwrite without confirmation
3. **Identify Audience**: Determine if contributors are internal-only, external, or mixed -- this affects language and channel references
4. **Gather Contact Info**: Confirm security contact, support channels, and escalation paths before generating -- placeholders must be filled
5. **Assess Compliance**: Check if the repository or organization has specific compliance requirements that affect security policy language
6. **Plan Scope**: Decide which documents to generate based on user request and what already exists

```
Does the repo already have governance docs?
├─ YES, all three → Ask if user wants to update/regenerate
├─ YES, some → Generate only missing ones (unless user specifies otherwise)
└─ NO → Generate all three (default)

Who are the contributors?
├─ Internal only → Can reference Teams channels, intranet links
├─ External / Open source → Must use publicly accessible channels
└─ Mixed → Provide both internal and external paths
```

---

## Process

### Step 1: Before Proceeding

Gather required information:
1. **Read** existing repo files: `README.md`, `CONTRIBUTING.md`, any existing governance docs
2. **Verify** the repository name, organization, and security contact are known
3. **Confirm** which documents to generate (default: all three)
4. **Check** for existing governance files to avoid overwriting

### Step 2: Determine Scope

- Which documents to generate (default: all three)
- Check for existing files to avoid overwriting
- Confirm contact information is available for all required fields

### Step 3: Gather and Validate Context

- Security reporting process and response SLAs
- Support channels and escalation paths
- Company conduct standards and HR alignment
- Compliance requirements (if applicable)

### Step 4: Generate Documents

- Each document is a separate file in the repository root
- Tailor content to the specific repo and company
- Replace ALL placeholders with actual values -- no `[PLACEHOLDER]` tokens in final output

### Step 5: Validate Output

Before finalizing, verify:
- No internal-only URLs that external contributors cannot access (if repo is public)
- Contact information is accurate and current
- Consistent with company-wide policies
- No leftover placeholder tokens in generated files
- Response time commitments are realistic

### Step 6: Self-Check

Ask yourself before delivering:
- Did I check for existing governance files first?
- Are all `[PLACEHOLDER]` values replaced with real information?
- Is the security reporting process clearly separated from public channels?
- Are the SLA commitments realistic for this team's capacity?
- Would a new contributor understand where to go for each type of issue?

---

## Output: SECURITY.md

```markdown
# Security Policy

## Reporting a Vulnerability

**Do NOT report security vulnerabilities through public issues, discussions, or pull requests.**

If you discover a security vulnerability in this repository, please report it responsibly:

1. **Email**: Send details to [SECURITY_EMAIL]
2. **Subject line**: `[SECURITY] [REPO_NAME] - Brief description`
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to expect

| Timeframe | Action |
|-----------|--------|
| 1 business day | Acknowledgment of your report |
| 5 business days | Initial assessment and severity classification |
| 30 days | Fix developed and tested (for confirmed vulnerabilities) |

We will keep you informed of progress and may ask for additional information.

## Supported Versions

| Version | Supported |
|---------|-----------|
| [LATEST_MAJOR].x | Yes |
| [PREVIOUS_MAJOR].x | Security fixes only |
| < [PREVIOUS_MAJOR] | No |

## Security Practices

This repository follows these security practices:
- Dependencies are regularly scanned for known vulnerabilities
- CI/CD pipeline includes security checks
- Code reviews are required for all changes
- Secrets are managed through [SECRET_MANAGEMENT_APPROACH]

## Disclosure Policy

- We follow [DISCLOSURE_POLICY_TYPE] (coordinated disclosure / responsible disclosure)
- We credit reporters in release notes (unless they prefer anonymity)
- We aim to fix confirmed vulnerabilities within 30 days

---

*Last updated: [DATE]*
```

---

## Output: CODE_OF_CONDUCT.md

```markdown
# Code of Conduct

## Our Standards

We are committed to providing a welcoming and professional environment for everyone.
All contributors, maintainers, and participants are expected to:

### Expected behavior

- **Be respectful**: Treat colleagues with courtesy and professionalism
- **Be constructive**: Provide helpful, specific feedback in reviews and discussions
- **Be collaborative**: Share knowledge, help others learn, and welcome new contributors
- **Be accountable**: Own your mistakes, learn from them, and help fix them
- **Be inclusive**: Use welcoming and inclusive language

### Unacceptable behavior

- Harassment, discrimination, or intimidation of any kind
- Personal attacks, insults, or derogatory comments
- Publishing others' private information without consent
- Deliberate sabotage of code, builds, or infrastructure
- Any conduct that would be considered unprofessional in a workplace

## Scope

This code of conduct applies to all interactions within this repository,
including issues, pull requests, code reviews, commit messages, and
associated communication channels (Teams, email, etc.).

## Enforcement

### Reporting

If you experience or witness unacceptable behavior:
1. Contact [MANAGER_OR_HR_CONTACT] directly
2. Or email [CONDUCT_EMAIL]

All reports will be handled confidentially and promptly.

### Consequences

Violations may result in:
1. **Warning**: Private conversation about the behavior
2. **Temporary restriction**: Limited access to the repository
3. **Removal**: Permanent removal from the project

## Attribution

This Code of Conduct is adapted from the [Contributor Covenant](https://www.contributor-covenant.org/),
version 2.1, tailored to our organizational context.

---

*Last updated: [DATE]*
```

---

## Output: SUPPORT.md

```markdown
# Support

## Getting Help

Before opening an issue or contacting the team, please check these resources:

### Documentation

| Resource | Location |
|----------|----------|
| README | [./README.md](./README.md) |
| Contributing Guide | [./CONTRIBUTING.md](./CONTRIBUTING.md) |
| Architecture Docs | [ARCHITECTURE_DOCS_LINK] |
| API Documentation | [API_DOCS_LINK] |

### Common Questions

**Q: How do I set up the project locally?**
A: See the [Installation/Setup section](./README.md#installationsetup) in the README.

**Q: How do I contribute?**
A: See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full workflow.

**Q: The build is failing. What do I do?**
A: Check the pipeline logs first. Common fixes:
1. `[RESTORE_COMMAND]` -- restore dependencies
2. `[FORMAT_COMMAND]` -- fix formatting issues
3. `[BUILD_COMMAND]` -- rebuild and check compiler output

## Contact Channels

| Channel | Purpose | Response Time |
|---------|---------|---------------|
| [TEAMS_CHANNEL_LINK] | General questions, quick help | Same day |
| [EMAIL_OR_DIST_LIST] | Detailed technical questions | 1-2 business days |
| [ISSUE_TRACKER_LINK] | Bug reports and feature requests | Triaged within 1 week |

## Reporting Issues

### Bug reports

Use the issue tracker and include:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Environment details (OS, SDK version, etc.)

### Feature requests

Use the issue tracker with:
- Description of the desired behavior
- Business justification or use case
- Impact if not implemented

## Escalation

If your issue is urgent or not being addressed:
1. Tag the repository owner in the issue/PR
2. Contact the team lead via [TEAMS_OR_EMAIL_ESCALATION]
3. Raise in the team's daily standup or retrospective

## What This Repo Does NOT Support

- [OUT_OF_SCOPE_TOPIC_1]
- [OUT_OF_SCOPE_TOPIC_2]
- For [RELATED_TOPIC], see [OTHER_REPO_OR_TEAM]

---

*Last updated: [DATE]*
```

---

## Examples (Few-Shot)

### Example 1: Generate All Governance Docs for Internal Repo

**Input**:
```
@create-repo-governance-docs ./

Context:
- Repository: eneve.domain
- Organization: Energy21
- Security contact: security@energy21.nl
- Support channel: Teams > Eneve Development
- Scope: all
```

**Reasoning**: All three documents are requested. The repo is internal, so we can reference Teams channels and internal tooling. No existing governance docs found, so generating fresh files.

**Output**: Three files created at repo root:
- `SECURITY.md` with `security@energy21.nl` as contact, coordinated disclosure policy, version support table populated from repo tags
- `CODE_OF_CONDUCT.md` with Contributor Covenant base, referencing Energy21 HR for enforcement
- `SUPPORT.md` with Teams > Eneve Development as primary channel, Azure DevOps boards for issue tracking

### Example 2: Generate Only SECURITY.md with Compliance Requirements

**Input**:
```
@create-repo-governance-docs ./

Context:
- Scope: security
- Security contact: security@energy21.nl
- Supported versions: 3.x (current), 2.x (security only)
- Compliance: ISO 27001
```

**Reasoning**: Only SECURITY.md requested. ISO 27001 compliance adds requirements for incident response documentation and audit trail. Version support table can be populated directly from provided versions.

**Output**: Single `SECURITY.md` file with:
- ISO 27001-aligned vulnerability reporting process
- Version support table: 3.x (full), 2.x (security only), <2.x (unsupported)
- 1/5/30 day SLA timeline
- Reference to company ISO 27001 incident response procedure

### Example 3: Batch Mode Across Multiple Repos

**Input**:
```
@create-repo-governance-docs ./

Apply to repos: eneve.domain, eneve.ebase.foundation, eneve.ebase.datamigrator
Shared context:
- Organization: Energy21
- Security contact: security@energy21.nl
- Code of conduct: Standard company policy
```

**Reasoning**: Batch generation for 3 repos. Since these share the same organization, SECURITY.md and CODE_OF_CONDUCT.md will be nearly identical. SUPPORT.md will differ per repo (different Teams channels, different maintainers). Generating shared templates first, then customizing SUPPORT.md per repo.

**Output**: For each repo, three files with shared security/conduct content and repo-specific support channels and documentation links.

---

## Usage Modes

### Generate all governance docs
```
@create-repo-governance-docs ./

Context:
- Organization: Energy21
- Security contact: security@energy21.nl
- Support channel: Teams > Eneve Development
- Scope: all
```

### Generate specific document
```
@create-repo-governance-docs ./

Context:
- Scope: security
- Security contact: security@energy21.nl
- Supported versions: 3.x (current), 2.x (security only)
```

### Batch mode (multiple repos)
```
@create-repo-governance-docs ./

Apply to repos: eneve.domain, eneve.ebase.foundation, eneve.ebase.datamigrator
Shared context:
- Organization: Energy21
- Security contact: security@energy21.nl
- Code of conduct: Standard company policy
```

---

## Quality Criteria

- [ ] All requested documents present (SECURITY.md, CODE_OF_CONDUCT.md, SUPPORT.md)
- [ ] Security reporting process is clear and does NOT use public channels
- [ ] All `[PLACEHOLDER]` tokens replaced with actual values in generated files
- [ ] Contact information is accurate and current
- [ ] No internal-only URLs in repos with external contributors
- [ ] Documents are consistent with company-wide policies
- [ ] Response time commitments are realistic and agreed upon
- [ ] Documents are concise and actionable (not walls of legalese)
- [ ] Last updated date included on each document
- [ ] Existing governance files were checked before generating (no accidental overwrites)
- [ ] Each document can stand alone -- a reader doesn't need to read all three

---

## Troubleshooting

**Issue**: Prompt generates docs with leftover `[PLACEHOLDER]` tokens
**Cause**: Required context was not provided (security contact, support channels, etc.)
**Solution**: Re-run with all Required Context fields filled in. Check the generated files for any remaining `[` brackets.

**Issue**: SUPPORT.md references Teams channels that external contributors cannot access
**Cause**: Repo has external contributors but support channels are internal-only
**Solution**: Add a public contact method (email distribution list, public issue tracker) alongside internal channels.

**Issue**: SECURITY.md SLA commitments are unrealistic for a small team
**Cause**: Default SLAs (1/5/30 days) may not fit every team's capacity
**Solution**: Adjust SLA timeframes in the Optional Context before generating. For small teams, consider 3/10/60 day windows.

**Issue**: CODE_OF_CONDUCT.md enforcement section lacks specific contacts
**Cause**: HR or management contacts were not provided
**Solution**: Provide `[MANAGER_OR_HR_CONTACT]` and `[CONDUCT_EMAIL]` in context. For company-wide policies, link to the authoritative HR document instead of duplicating.

---

## Company Policy Alignment

These documents should align with:
- Company-wide security policies (incident response, vulnerability disclosure)
- HR policies for code of conduct (harassment, discrimination, enforcement)
- IT support SLA agreements (response times, escalation paths)
- Compliance requirements (ISO 27001, SOC2, GDPR -- if applicable)

When in doubt, link to the authoritative company-wide policy rather than duplicating it.
This keeps governance docs maintainable -- update the policy once, not in every repo.

---

## Related Prompts

- `documentation/create-readme.prompt.md` - Create repo-level README
- `documentation/create-contributing-guide.prompt.md` - Create CONTRIBUTING.md
- `documentation/create-project-landing-page.prompt.md` - Create Azure DevOps Project page
- `documentation/validate-documentation-quality.prompt.md` - Validate all documentation

---

## Related Rules

- `.cursor/rules/prompts/prompt-creation-rule.mdc` - Prompt creation standards
- `.cursor/rules/prompts/prompt-registry-integration-rule.mdc` - Registry format requirements
- `.cursor/rules/documentation/agent-application-rule.mdc` - Documentation standards guidance

---

**Created**: 2026-02-17
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0
**Improved**: 2026-02-17 (improve-prompt + enhance-prompt dual pass)
