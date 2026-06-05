---
name: create-project-landing-page
description: "Please generate an Azure DevOps Project landing page (wiki/README) that orients new team members"
agent: cursor-agent
tools:
  - search/codebase
  - fileSystem
argument-hint: "Project name (e.g., Eneve, NuGet Packages)"
category: documentation
tags: documentation, azure-devops, project, landing-page, onboarding, wiki
rules:
  - .cursor/rules/prompts/prompt-creation-rule.mdc
---

# Create Azure DevOps Project Landing Page

Generate a landing page for an Azure DevOps Project. This is **not** a repo README -- it is the project-level overview page that appears when someone visits the Azure DevOps Project in their browser (e.g., `dev.azure.com/OrgName/ProjectName`).

**Pattern**: Project Documentation ⭐⭐⭐⭐⭐
**Effectiveness**: Eliminates "I found the project but don't know what's in it" confusion
**Use When**: Setting up a new Azure DevOps Project, or the existing project page is empty/outdated

---

## Purpose

Azure DevOps Projects group multiple repositories, pipelines, boards, and artifacts under one umbrella. The project landing page is the **first thing people see** when they navigate to the project. An empty page signals abandonment; a good page gets people productive in minutes.

This prompt creates the project-level wiki page or README that:
- Explains **what the project is about** (business context, not code)
- Lists **all repositories** in the project with one-line descriptions
- Points to **key resources** (boards, pipelines, feeds, documentation)
- Answers **who owns what** and how to get help

---

## Required Context

- **Project name**: The Azure DevOps Project name
- **Organization**: The Azure DevOps organization (e.g., `Energy21`)
- **Business purpose**: What business domain or initiative this project supports
- **Repositories**: List of repos in the project with brief descriptions
- **Team/ownership**: Who owns the project, key contacts

### Optional Context (improves quality)

- **Pipelines**: Key CI/CD pipelines and what they build
- **Artifact feeds**: NuGet/npm feeds hosted in the project
- **Boards**: Work item tracking setup (Scrum/Kanban, area paths)
- **Environments**: DEV/TEST/STAGING/PROD topology
- **Related projects**: Other Azure DevOps Projects this one depends on or feeds into
- **External links**: Confluence, SharePoint, or other documentation sites

---

## Reasoning Process (for AI Agent)

Before generating the landing page, the AI should:

1. **Determine project type**: Is this a product, a platform, a shared library collection, or a migration workspace? The type determines which sections to emphasize.
2. **Assess completeness of context**: What information has the user provided vs. what needs to be discovered? Use `search/codebase` to find repo READMEs, pipeline definitions, and existing documentation.
3. **Identify the audience**: New team members? External contributors? Migration team? Tailor the "Getting Started" section accordingly.
4. **Decide section depth**: Projects with 1-2 repos need less architecture detail than projects with 5+ interconnected repos. Skip sections that don't apply rather than filling them with placeholder text.
5. **Validate against anti-patterns**: Before outputting, check for walls of text (use tables), missing links (use placeholders with clear `[TODO: ...]` markers), and exposed credentials.

---

## Process

1. **Identify the project scope**
   - What business domain does this project serve?
   - Is it a product, a platform, a shared library collection, or a migration workspace?

2. **Inventory the repositories**
   - List all repos with one-line descriptions
   - Note which are active vs archived
   - Identify the "main" repo if there is one

3. **Map the infrastructure**
   - Pipelines (what they build, where they deploy)
   - Artifact feeds (NuGet, npm, etc.)
   - Environments and deployment targets

4. **Document access and ownership**
   - Project admin / owner
   - Key contacts per repo or area
   - How to request access

5. **Generate the landing page**
   - Follow the output format below
   - Keep it scannable (tables, bullet lists, short paragraphs)

6. **Self-review before outputting**
   - Does every section add value for a newcomer?
   - Are all repo links correct and descriptions meaningful (not just the repo name repeated)?
   - Is the "Getting Started" section actionable within 5 minutes?
   - Are there any empty sections that should be removed or marked `[TODO]`?

---

## Constraints

- **No secrets or credentials**: Never include connection strings, API keys, tokens, or internal IP addresses
- **No placeholder-heavy output**: If a section would be mostly `[TODO: fill in]`, omit it and note it as a follow-up action instead
- **Scannable over comprehensive**: Prefer tables and bullet lists over narrative paragraphs; a newcomer should find what they need in under 60 seconds
- **Links must be functional**: Use actual Azure DevOps URL patterns (`dev.azure.com/Org/Project/_git/repo`) or clearly mark as `[TODO: add link]`
- **Keep it current**: Always include a "Last updated" date at the bottom

---

## Output Format

```markdown
# [Project Name]

[1-2 sentence business context. What is this project about and why does it exist?]

## Repositories

| Repository | Description | Status | Primary Language |
|------------|-------------|--------|-----------------|
| [repo-name](link) | One-line description | Active / Archived | C# / Python / etc. |
| ... | ... | ... | ... |

## Getting Started

### For new team members
1. Request access to the `[ProjectName]` project from [admin name/team]
2. Clone the repository you need: `git clone [url]`
3. Follow the README in each repository for setup instructions

### Key links
| Resource | Link |
|----------|------|
| Boards (Work Items) | [link to boards] |
| Pipelines | [link to pipelines] |
| Artifact Feeds | [link to feeds] |
| Documentation | [link to docs site or wiki] |

## Architecture Overview

[Brief description of how the repositories relate to each other.
Include a diagram if the project has 3+ repos with dependencies.]

## Pipelines & CI/CD

| Pipeline | Repository | Triggers | What It Does |
|----------|-----------|----------|-------------|
| [pipeline-name] | [repo] | Branch / Tag | Build, test, publish |
| ... | ... | ... | ... |

## Artifact Feeds

| Feed | Type | Purpose | Consumers |
|------|------|---------|-----------|
| [feed-name] | NuGet / npm | [what packages] | [who uses them] |
| ... | ... | ... | ... |

## Team & Ownership

| Role | Person/Team | Contact |
|------|-------------|---------|
| Project Admin | [name] | [email or Teams link] |
| Technical Lead | [name] | [email or Teams link] |
| ... | ... | ... |

## Related Projects

| Project | Relationship |
|---------|-------------|
| [OtherProject](link) | Consumes NuGet packages from this project |
| ... | ... |

---

*Last updated: [date]*
```

---

## Usage

### Basic (generate from provided context)

```
/create-project-landing-page NuGet Packages
```

Then provide the required context (project name, org, repos, team) in the conversation.

### Comprehensive (with full context upfront)

```
/create-project-landing-page

Project: NuGet Packages
Organization: Energy21
Purpose: Shared .NET libraries published as NuGet packages
Repos: eneve.domain, eneve.ebase.foundation, eneve.ebase.datamigrator
Pipelines: Build + publish per repo
Feed: Eneve.Domain NuGet feed
Owner: John van der Pol
```

### Migration-focused (for projects receiving migrated repos)

```
/create-project-landing-page

Project: Eneve
Organization: Energy21
Purpose: Migration target for GitLab repos
Status: Repos being migrated from GitLab
Migration lead: [name]
```

---

## Examples (Few-Shot)

### Example 1: NuGet Package Library Project

**Input**:
```
Project: NuGet Packages
Organization: Energy21
Purpose: Shared .NET libraries published as NuGet packages
Repos: eneve.domain, eneve.ebase.foundation, eneve.ebase.datamigrator
```

**Output (excerpt)**:
```markdown
# NuGet Packages

Shared .NET libraries and domain foundations for the Eneve/eBase platform, published as NuGet packages to internal Azure Artifacts feeds.

## Repositories

| Repository | Description | Status | Primary Language |
|------------|-------------|--------|-----------------|
| [eneve.domain](./eneve.domain) | Domain-Driven Design foundation with domain objects, caching, and persistence | Active | C# (.NET 9) |
| [eneve.ebase.foundation](./eneve.ebase.foundation) | eBase platform foundation and shared infrastructure | Active | C# (.NET 9) |
| [eneve.ebase.datamigrator](./eneve.ebase.datamigrator) | Data migration tooling for eBase system tables | Active | C# (.NET 9) |

## Getting Started

### For new team members
1. Request access to `NuGet Packages` project from John van der Pol
2. Install .NET 9 SDK: https://dotnet.microsoft.com/download
3. Clone the repository you need and follow its README

### Key links
| Resource | Link |
|----------|------|
| Artifact Feed | [Eneve.Domain Feed](https://dev.azure.com/Energy21/NuGet%20Packages/_artifacts/feed/Eneve.Domain) |
| Pipelines | [All Pipelines](https://dev.azure.com/Energy21/NuGet%20Packages/_build) |
| Boards | [Work Items](https://dev.azure.com/Energy21/NuGet%20Packages/_boards) |
```

### Example 2: Empty Project (Migration Target)

**Input**:
```
Project: Eneve
Organization: Energy21
Purpose: Migration target for GitLab repos related to the Eneve platform
Repos: (none yet, repos being migrated from GitLab)
```

**Output (excerpt)**:
```markdown
# Eneve

Azure DevOps Project for the Eneve platform. Repositories are being migrated from GitLab as part of the 2026 platform migration.

## Repositories

| Repository | Description | Status | Migration Status |
|------------|-------------|--------|-----------------|
| *(repos being migrated)* | See [Migration Tracker](link) for current status | - | In Progress |

## Getting Started

### For the migration team
1. See the [GitLab Migration Runbook](link) for the migration process
2. Each migrated repo will have its own README with setup instructions
3. CI/CD pipelines will be translated from `.gitlab-ci.yml` to Azure Pipelines YAML

### For future developers
This page will be updated as repositories are migrated. Check back or contact the migration team.

## Team & Ownership

| Role | Person | Contact |
|------|--------|---------|
| Migration Lead | [name] | [contact] |
| Platform Architect | [name] | [contact] |
```

### Example 3: Multi-Team Platform Project

**Input**:
```
Project: eBase Platform
Organization: Energy21
Purpose: Core energy trading and portfolio management platform
Repos: ebase-api, ebase-ui, ebase-contracts, ebase-scheduler, ebase-reports
Teams: Backend (API + scheduler), Frontend (UI), Shared (contracts + reports)
```

**Output (excerpt)**:
```markdown
# eBase Platform

Core energy trading and portfolio management platform serving commercial and operational teams. Comprises backend services, a web UI, shared contract libraries, and reporting infrastructure.

## Repositories

| Repository | Description | Status | Team | Primary Language |
|------------|-------------|--------|------|-----------------|
| [ebase-api](./ebase-api) | REST API for trade execution, portfolio management, and market data | Active | Backend | C# (.NET 9) |
| [ebase-ui](./ebase-ui) | Web front-end for traders and portfolio managers | Active | Frontend | TypeScript (React) |
| [ebase-contracts](./ebase-contracts) | Shared DTOs, enums, and API contracts consumed by all services | Active | Shared | C# (.NET 9) |
| [ebase-scheduler](./ebase-scheduler) | Background job scheduler for settlement, reporting, and data sync | Active | Backend | C# (.NET 9) |
| [ebase-reports](./ebase-reports) | SSRS/Power BI report definitions and data export pipelines | Active | Shared | SQL / C# |

## Architecture Overview

```
ebase-ui ──► ebase-api ──► ebase-scheduler
    │              │               │
    └──────────────┴───────────────┘
                   │
           ebase-contracts (shared by all)
                   │
           ebase-reports (reads from API data stores)
```

## Team & Ownership

| Role | Person/Team | Contact | Scope |
|------|-------------|---------|-------|
| Platform Lead | [name] | [contact] | All repos |
| Backend Lead | [name] | [contact] | ebase-api, ebase-scheduler |
| Frontend Lead | [name] | [contact] | ebase-ui |
| Shared Libraries | [name] | [contact] | ebase-contracts, ebase-reports |
```

---

## Troubleshooting & Common Pitfalls

**Issue**: Landing page becomes a wall of text that nobody reads
**Cause**: Writing narrative paragraphs instead of using tables and lists
**Solution**: Enforce the scannable format -- every multi-item list should be a table, every section opening should be 1-2 sentences max

**Issue**: Links go stale within weeks
**Cause**: Hardcoding URLs that change when projects/repos are renamed
**Solution**: Use relative links where possible (`./repo-name`), and include the "Last updated" date so staleness is visible

**Issue**: "Getting Started" section is too generic to be useful
**Cause**: Writing for an abstract audience instead of the actual newcomer
**Solution**: Include specific tool versions (e.g., ".NET 9 SDK"), specific access contacts (names, not "your admin"), and specific first-clone commands

**Issue**: Project has repos that belong to different business domains
**Cause**: Azure DevOps Project was used as a catch-all
**Solution**: Group repos by domain in the table using subheadings, or recommend splitting into separate projects

---

## Quality Criteria

- [ ] Business purpose clearly stated in first 1-2 sentences
- [ ] All repositories listed with descriptions and status
- [ ] Getting started section provides actionable first steps (specific tools, contacts, commands)
- [ ] Key links table populated (boards, pipelines, feeds, docs) with real URLs or explicit `[TODO]` markers
- [ ] Team ownership documented with contact info
- [ ] No secrets, internal IPs, or credentials exposed
- [ ] Page is scannable (tables and bullet lists, not walls of text)
- [ ] Architecture overview present for projects with 3+ repos
- [ ] Related projects cross-referenced where applicable
- [ ] Last updated date included
- [ ] Empty/inapplicable sections omitted rather than filled with placeholders
- [ ] All repo descriptions are meaningful (not just the repo name repeated)

---

## Related Prompts

- `documentation/create-readme.prompt.md` - Create a repo-level README (inside a specific repository)
- `documentation/create-contributing-guide.prompt.md` - Create CONTRIBUTING.md for a repository
- `documentation/create-repo-governance-docs.prompt.md` - Create SECURITY.md, CODE_OF_CONDUCT.md, SUPPORT.md
- `git/analyze-gitlab-repo.prompt.md` - Analyze repos for migration decisions

---

## Related Rules

- `.cursor/rules/prompts/prompt-creation-rule.mdc` - Prompt creation standards
- `.cursor/rules/prompts/prompt-registry-integration-rule.mdc` - Registry format requirements
- `.cursor/rules/documentation/agent-application-rule.mdc` - Documentation standards guidance

---

**Created**: 2026-02-17
**Improved**: 2026-02-17 (improve-prompt + enhance-prompt combined pass)
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0
