---
name: create-contributing-guide
description: "Please generate a CONTRIBUTING.md with company-standard contribution guidelines"
agent: cursor-agent
tools:
  - search/codebase
  - fileSystem
argument-hint: "Repository root path (e.g., ./ ) or specific context about the repo"
category: documentation
tags: documentation, contributing, onboarding, governance, policy, company-standard
rules:
  - .cursor/rules/prompts/prompt-creation-rule.mdc
  - .cursor/rules/prompts/prompt-registry-integration-rule.mdc
---

# Create Contributing Guide

Please generate a `CONTRIBUTING.md` file that establishes clear, company-standard contribution guidelines for a repository.

**Pattern**: Repository Governance Documentation ⭐⭐⭐⭐⭐
**Effectiveness**: Prevents contribution friction and enforces consistent workflows
**Use When**: A repository has no CONTRIBUTING.md, or the existing one is outdated/incomplete

---

## Purpose

A `CONTRIBUTING.md` is the single source of truth for **how** to contribute to a repository. It prevents:
- Rejected PRs due to unknown conventions
- Inconsistent branch naming and commit messages
- Missing tests or documentation on new features
- Time wasted explaining the same process to each new contributor

This prompt generates a company-standard CONTRIBUTING.md tailored to the specific repository's technology stack and workflow.

---

## Required Context

- **Repository name and purpose**: What the repo contains
- **Primary language/framework**: .NET, Python, Node.js, etc.
- **Branching strategy**: main/develop, trunk-based, or project-specific
- **CI/CD pipeline**: What checks run, what must pass before merge
- **Code review process**: Who reviews, approval requirements

### Optional Context (improves quality)

- **Build commands**: How to build, test, lint, format
- **Branch naming convention**: e.g., `feature/EPP-123-description`
- **Commit message convention**: e.g., Conventional Commits, ticket-prefix
- **Test requirements**: Coverage thresholds, required test types
- **Documentation requirements**: XML docs, README updates, changelog
- **Release process**: Tag-based, manual, automated
- **Internal tooling**: Cursor prompts, scripts, quality gates
- **Restricted areas**: Files/folders that need special approval

---

## Reasoning Process (for AI Agent)

Before generating the CONTRIBUTING.md, the AI should:

1. **Understand the Repository**: Read project files to determine the technology stack, build system, and existing conventions. Do not assume -- verify from actual files.
2. **Identify Existing Standards**: Check for `.editorconfig`, CI/CD configs, existing docs, and `.cursor/rules/` that reveal the team's actual workflow.
3. **Map the Contribution Lifecycle**: Trace the full path from "developer wants to make a change" to "change is merged and deployed." Every step in that path belongs in the guide.
4. **Prioritize Accuracy Over Completeness**: It is better to leave a placeholder (`[TODO: confirm with team]`) than to fabricate a convention the team does not follow. Every command must be copy-pasteable and correct.
5. **Adapt to the Stack**: Use the technology-specific commands table in the Tailoring section. Do not write `npm test` for a .NET project.
6. **Include Mandatory Company Sections**: Branching strategy, commit convention, PR review requirements, quality gates, and documentation requirements are non-negotiable regardless of repository type.

---

## Process

### Step 1: Scan the Repository

- Identify technology stack from project files (`.csproj`, `package.json`, `pyproject.toml`)
- Check for existing CI/CD configuration (`.yml` pipelines, `.github/workflows/`)
- Look for `.editorconfig`, linting configs, build scripts
- Check for existing branching rules or conventions
- Read any existing `CONTRIBUTING.md`, `README.md`, or `DEVELOPMENT.md` for current guidance

### Step 2: Determine Contribution Workflow

- Map the branch-to-merge lifecycle
- Identify quality gates (build, test, lint, security, coverage)
- Note any special approval or review requirements
- Document the PR template or checklist if one exists

### Step 3: Draft the CONTRIBUTING.md

- Follow the output format below
- Tailor commands and examples to the actual repository
- Include real build/test/lint commands (not placeholders)
- Ensure every command is copy-pasteable and verified

### Step 4: Validate

- All commands are copy-pasteable and correct for the repository's actual tooling
- No internal secrets or credentials exposed
- Consistent with existing CI/CD pipeline requirements
- Company mandatory sections are all present

### Step 5: Self-Review

Before finalizing, verify:
- Did I use the repository's actual commands, not generic ones?
- Are the branch naming examples consistent with the branching strategy section?
- Does the PR checklist match what the CI/CD pipeline actually enforces?
- Would a new hire be able to follow this guide from clone to merged PR without asking questions?

If any check fails, revise before presenting.

---

## Output Format

The generated CONTRIBUTING.md should follow this structure:

**Deliverables**:
1. A complete `CONTRIBUTING.md` file ready to commit
2. Tailored to the repository's actual stack and workflow
3. All commands verified against the repository

**File Structure**:

```markdown
# Contributing to [Repository Name]

Thank you for contributing. This guide explains the workflow, conventions, and
quality standards for this repository.

## Prerequisites

- [Technology SDK/Runtime] version [X.Y] or later
- Git 2.x or later
- [IDE/Editor recommendation] (optional)
- Access to [Azure DevOps project / GitLab group] (request from [contact])

## Getting Started

1. Clone the repository:
   ```bash
   git clone [repo-url]
   cd [repo-name]
   ```

2. Install/restore dependencies:
   ```bash
   [restore command]
   ```

3. Build the project:
   ```bash
   [build command]
   ```

4. Run the tests:
   ```bash
   [test command]
   ```

## Branching Strategy

We use [strategy name] with the following branch types:

| Branch Type | Pattern | Base Branch | Merges Into |
|-------------|---------|-------------|-------------|
| Feature | `feature/[TICKET]-[description]` | `develop` | `develop` |
| Bug Fix | `fix/[TICKET]-[description]` | `develop` | `develop` |
| Hotfix | `hotfix/[TICKET]-[description]` | `main` | `main` + `develop` |
| Release | `release/[version]` | `develop` | `main` + `develop` |

### Branch naming rules
- Always include the ticket/work-item ID
- Use lowercase with hyphens for the description
- Keep descriptions short but meaningful

## Commit Messages

[Convention name] format:

```
[type]([scope]): [TICKET-ID] [Short description]

[Optional body explaining the change]
```

**Types**: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `ci`

**Examples**:
```
feat(cache): EPP-192 Add distributed cache invalidation
fix(domain): EBASE-1234 Handle null reference in DomainObject.Key
docs(readme): EPP-192 Update installation instructions
test(unit): EPP-192 Add coverage for SelectKey edge cases
```

## Making Changes

### Step-by-step workflow

1. **Create a branch** from `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/EPP-123-my-feature
   ```

2. **Make your changes** following the code standards below

3. **Run quality checks locally**:
   ```bash
   [build command]
   [test command]
   [format/lint command]
   ```

4. **Commit your changes** using the commit message convention above

5. **Push and create a Pull Request**:
   ```bash
   git push -u origin feature/EPP-123-my-feature
   ```
   Then create a PR targeting `develop` in [Azure DevOps / GitLab]

6. **Address review feedback** and ensure all pipeline checks pass

## Code Standards

### Style and formatting
- [Auto-formatter tool and command]
- [Linting tool and command]
- [Editor config reference]

### Testing requirements
- All new code must have unit tests
- Minimum coverage threshold: [X]%
- Run tests: `[test command]`
- [Specific testing framework/conventions]

### Documentation requirements
- Public APIs must have [XML docs / docstrings / JSDoc]
- Update README if adding new features or changing setup
- Update CHANGELOG for user-facing changes

## Pull Request Process

### Before submitting
- [ ] Code builds without errors or warnings
- [ ] All tests pass
- [ ] Code formatted with [tool]
- [ ] Documentation updated (if applicable)
- [ ] Commit messages follow convention
- [ ] Branch is up to date with `develop`

### Review process
- Minimum [N] approval(s) required
- [Specific reviewer assignments or CODEOWNERS reference]
- All pipeline checks must pass (build, test, lint, security)
- Review comments must be resolved before merge

### After merge
- Delete the feature branch
- Verify the pipeline completes successfully on `develop`
- Update work items / tickets to reflect progress

## CI/CD Pipeline

The following checks run automatically on every PR:

| Check | What It Does | Must Pass |
|-------|-------------|-----------|
| Build | Compiles the solution | Yes |
| Unit Tests | Runs all unit tests | Yes |
| Code Format | Validates consistent formatting | Yes |
| [Additional checks] | [Description] | [Yes/No] |

## Getting Help

- **Questions about this repo**: Contact [owner/team]
- **Access requests**: Contact [admin]
- **CI/CD issues**: Check pipeline logs or contact [team]
- **Documentation**: See [links to docs, wiki, or architecture guides]

---

*Last updated: [date]*
```

---

## Examples

### Example 1: .NET Library Repository

**Input**:
```
Repo: eneve.domain
Stack: .NET 9, C#
Branching: main/develop with feature branches
CI/CD: Azure Pipelines with 10-stage quality pipeline
Coverage threshold: 80%
```

**Reasoning**: .NET project uses `dotnet` CLI for build/test/format. Branch naming follows `feature/EPP-123-description` pattern. Azure Pipelines config determines the CI/CD checks table. XML documentation is mandatory for public APIs in .NET libraries.

**Output highlights**:
- Prerequisites: .NET 9 SDK
- Build: `dotnet build`, Test: `dotnet test`, Format: `dotnet format`
- Branch naming: `feature/EPP-123-description`
- Pipeline stages: Build, Test, Quality Gates, Coverage, Mutation Testing, Benchmarks
- Documentation: XML docs required on public APIs

### Example 2: Python Data Pipeline

**Input**:
```
Repo: data-pipeline
Stack: Python 3.12, Poetry
Branching: trunk-based
CI/CD: GitLab CI
Coverage threshold: 90%
```

**Reasoning**: Python with Poetry uses `poetry install` for deps and `pytest` for testing. Trunk-based means shorter-lived branches and more frequent merges. Higher coverage threshold (90%) reflects data pipeline reliability requirements.

**Output highlights**:
- Prerequisites: Python 3.12, Poetry
- Build: `poetry install`, Test: `pytest`, Format: `black . && isort .`
- Branch naming: `feature/JIRA-123-description`
- PR checks: lint, type-check, test, coverage
- Documentation: Docstrings (Google style) on all public functions

### Example 3: Node.js Microservice

**Input**:
```
Repo: order-service
Stack: Node.js 20, TypeScript, Express
Branching: main/develop
CI/CD: GitHub Actions
Coverage threshold: 85%
```

**Reasoning**: Node.js with TypeScript uses `npm` scripts. GitHub Actions workflows define CI checks. Conventional Commits can be enforced with `commitlint` and `husky`. TypeScript compilation is a build step that catches type errors before runtime.

**Output highlights**:
- Prerequisites: Node.js 20, npm
- Build: `npm run build`, Test: `npm test`, Lint: `npm run lint`
- Branch naming: `feature/PROJ-123-description`
- Commit convention: Conventional Commits (enforced by commitlint)

---

## Tailoring the Guide

### Technology-specific adaptations

| Stack | Build | Test | Format | Lint |
|-------|-------|------|--------|------|
| .NET | `dotnet build` | `dotnet test` | `dotnet format` | Analyzers via `Directory.Build.props` |
| Python | `pip install -e .` | `pytest` | `black .` | `flake8` or `ruff` |
| Node.js | `npm run build` | `npm test` | `prettier --write .` | `eslint .` |
| Go | `go build ./...` | `go test ./...` | `gofmt -w .` | `golangci-lint run` |

### Company policy sections (always include)

These sections are **mandatory** for all repositories as company policy:
- Branching strategy and naming
- Commit message convention
- PR review requirements
- Quality gate compliance
- Documentation requirements

---

## Troubleshooting

**Issue**: Generated commands don't match the repository's actual tooling.
**Cause**: AI relied on assumptions instead of reading project files.
**Solution**: Re-run with explicit build/test/lint commands provided in the input context, or point the prompt at the CI/CD pipeline config file.

**Issue**: Guide is too generic (placeholder-heavy).
**Cause**: Insufficient context provided -- the AI didn't have access to pipeline configs or project files.
**Solution**: Provide the optional context items (build commands, coverage thresholds, reviewer list) or ensure the repository root is accessible for scanning.

**Issue**: Missing company-mandatory sections.
**Cause**: Guide was generated without awareness of company policy requirements.
**Solution**: Re-run and verify all 5 mandatory sections are present: branching, commits, PR review, quality gates, documentation.

---

## Quality Criteria

- [ ] All commands are copy-pasteable and verified against actual repo tooling
- [ ] Branching strategy matches what the team actually uses
- [ ] CI/CD checks listed match the actual pipeline configuration
- [ ] Coverage thresholds match pipeline enforcement settings
- [ ] No secrets, internal IPs, or credentials exposed
- [ ] Contact information is accurate and up to date
- [ ] Guide works for both new hires and experienced contributors
- [ ] Technology-specific commands match the repo's actual stack
- [ ] All 5 company-mandatory sections present (branching, commits, PR review, quality gates, docs)
- [ ] A new hire could follow the guide from clone to merged PR without asking additional questions

---

## Usage

**Basic** (scan current repository):
```
/create-contributing-guide ./
```

**With specific context**:
```
/create-contributing-guide .NET 9 library, main/develop branching, Azure Pipelines, 80% coverage
```

**For a different repository**:
```
/create-contributing-guide path/to/other/repo with Python 3.12 and GitLab CI
```

---

## Related Prompts

- `documentation/create-readme.prompt.md` - Create the repo-level README
- `documentation/create-project-landing-page.prompt.md` - Create Azure DevOps Project page
- `documentation/create-repo-governance-docs.prompt.md` - Create SECURITY.md, CODE_OF_CONDUCT.md, SUPPORT.md
- `documentation/update-readme.prompt.md` - Update an existing README

---

## Related Rules

- `.cursor/rules/prompts/prompt-creation-rule.mdc` - Prompt creation standards
- `.cursor/rules/prompts/prompt-registry-integration-rule.mdc` - Registry format requirements
- `.cursor/rules/git/branch-naming-rule.mdc` - Branch naming conventions referenced in output
- `.cursor/rules/documentation/agent-application-rule.mdc` - Documentation standards

---

**Created**: 2026-02-17
**Improved**: 2026-02-17 (improve-prompt + enhance-prompt pass)
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0
