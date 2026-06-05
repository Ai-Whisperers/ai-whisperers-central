---
name: analyze-gitlab-repo
description: "Please analyze a GitLab repository to produce a migration decision report for GitLab-to-Azure migration"
category: git
tags: git, migration, gitlab, azure-devops, analysis, repository, decision, triage
argument-hint: "Repository name, GitLab URL, or CSV metadata row"
---

# Analyze GitLab Repository for Migration

Please analyze the provided GitLab repository and produce a comprehensive migration decision report to support a GitLab-to-Azure DevOps migration.

**Pattern**: Guided Analysis ⭐⭐⭐⭐⭐  
**Effectiveness**: Eliminates guesswork when triaging 100+ repos for platform migration  
**Use When**: Evaluating individual repositories for GitLab-to-Azure DevOps migration

---

## Purpose

During a GitLab-to-Azure migration, each repository needs a clear verdict: **migrate, archive, or abandon**. This prompt produces a structured report covering ownership, activity, value, CI/CD configuration, and migration complexity so stakeholders can make fast, informed decisions.

It works in two modes:
- **Metadata-only mode**: When you only have the GitLab export CSV row (no repo clone). Produces a triage-level assessment from available fields.
- **Deep-analysis mode**: When the repo is cloned locally. Adds content inspection, pipeline parsing, and secret scanning.

---

## Verdict Definitions

Three possible outcomes. Every analysis must end with exactly one:

| Verdict | Definition | Post-Migration Action |
|---------|-----------|----------------------|
| **MIGRATE** | Repository has business value and should move to Azure DevOps. Active or strategically important. | Clone to Azure Repos, translate CI/CD, configure policies, verify build. |
| **ARCHIVE** | Repository has historical/reference value but no active development. Worth preserving read-only. | Import to Azure Repos as read-only archive (or keep GitLab archive). No CI/CD needed. |
| **ABANDON** | Repository has no business value. Empty, personal experiments, obsolete forks, or departed-employee hobby projects. | Mark as archived in GitLab, do not migrate. Document reason for audit trail. |

---

## Repository Archetypes

Most enterprise GitLab repos fall into one of these patterns. Identifying the archetype early speeds up analysis:

| Archetype | Signals | Typical Verdict |
|-----------|---------|----------------|
| **Production Codebase** | High commit count, active CI/CD, protected branches, multiple contributors, recent activity | MIGRATE |
| **Documentation Site** | DocFX/MkDocs config, referenced in docs-site mapping, `.yml` table-of-contents, pipeline builds docs | MIGRATE |
| **Script Library** | Customer/client namespace, GenScript or SQL files, protected environment branches (Acceptance/Test/Production) | MIGRATE |
| **Blueprint / Config** | `blueprints/` namespace, domain-specific configuration, moderate commits, may be stale but referenced by running systems | MIGRATE or ARCHIVE |
| **Internal Tooling** | `tools/` or `system-team/` namespace, automation scripts, moderate activity | MIGRATE or ARCHIVE |
| **Personal Fork** | `username/` namespace, forked from group repo, same or fewer commits as upstream | ABANDON |
| **POC / Experiment** | `e21labs/` namespace, low commits, no pipeline, private visibility, stale | ARCHIVE or ABANDON |
| **Empty Shell** | 0 commits, empty repo flag, placeholder or abandoned before use | ABANDON |
| **Departed Employee Project** | `username/` namespace, owner no longer employed, no group dependency, personal experiments | ABANDON |

---

## Required Context

Provide **at least one** of the following:

- **Option A - Repo metadata row** (from GitLab export CSV):

<repo_metadata>
[PASTE THE CSV/TABLE ROW FOR THIS REPOSITORY]
</repo_metadata>

- **Option B - Cloned repository** (local path):

<repo_path>
[LOCAL_PATH_TO_CLONED_REPO]
</repo_path>

- **Option C - GitLab URL** (if API access available):

<gitlab_url>
[GITLAB_WEB_URL]
</gitlab_url>

**Optional context** (improves accuracy):

- **Employee roster**: List of current employees and departed employees
- **Doc-site mapping**: Repos used as documentation site sources (DEV/PROD environments)
- **Known critical systems**: Repos powering production workloads
- **Client/customer list**: Namespace-to-customer mapping for client-specific repos

---

## Reasoning Process (for AI Agent)

Before generating the report, reason through:

1. **Classify the repo**: Match to an archetype above. Is it source code, documentation, scripts, blueprints/config, or a personal fork?
2. **Assess liveliness**: When was the last meaningful commit? Is there ongoing activity or is it dormant?
3. **Identify ownership**: Who owns it? Are they still at the company? Is there a bus factor of 1?
4. **Evaluate CI/CD**: Does it have pipelines? What do they build/deploy? Are there artifacts that matter?
5. **Gauge business value**: Does production depend on this? Is it referenced by other repos or doc sites?
6. **Estimate migration effort**: Simple git push, or does it need pipeline translation, secret migration, etc.?

---

## Decision Flowchart

```
Is the repo empty?
├─ YES → ABANDON
└─ NO
   ├─ Is it archived AND last commit > 4 years ago?
   │  ├─ YES → ABANDON
   │  └─ NO
   │     ├─ Is owner departed AND personal namespace AND no group dependency?
   │     │  ├─ YES → ABANDON (unless confirmed valuable by team)
   │     │  └─ NO
   │     │     ├─ Is it Active (commits < 6 months)?
   │     │     │  ├─ YES → MIGRATE
   │     │     │  └─ NO
   │     │     │     ├─ Is it a doc-site source (DEV or PROD)?
   │     │     │     │  ├─ YES → MIGRATE
   │     │     │     │  └─ NO
   │     │     │     │     ├─ Is it referenced by production systems?
   │     │     │     │     │  ├─ YES → MIGRATE
   │     │     │     │     │  └─ NO
   │     │     │     │     │     ├─ Is it Stale (6-24 months) with > 50 commits?
   │     │     │     │     │     │  ├─ YES → ARCHIVE (flag for team review)
   │     │     │     │     │     │  └─ NO
   │     │     │     │     │     │     ├─ Is it Dormant (> 24 months)?
   │     │     │     │     │     │     │  ├─ YES → ARCHIVE or ABANDON (team decides)
   │     │     │     │     │     │     │  └─ NO → ARCHIVE
```

---

## Process

### Step 1: Repository Identity

Gather basic facts:

- Repository name, namespace/group, and full path
- Project ID
- Visibility (public / internal / private)
- Created date and last activity date
- Archived status
- Empty repo status
- **Archetype classification** (match to table above)

### Step 2: Ownership & People

Determine who is responsible:

- **Project owner** (GitLab setting)
- **Last committer** and date of last commit
- **Top contributors** (if available from git log)
- **Are these people still employed?** (cross-reference with employee roster if provided)
- **Bus factor**: How many active contributors?
- Flag: `OWNER_DEPARTED` if the owner/primary committer is no longer at the company

**Metadata-only mode**: Use Project Owner and Last Committer fields. If no employee roster is provided, note "Employee status: UNKNOWN - verify manually".

### Step 3: Activity Assessment

Evaluate how alive the repository is:

| Metric | Value |
|--------|-------|
| Total commits | |
| Last commit date | |
| Last commit author | |
| Commits in last 12 months | (if available) |
| Commits in last 6 months | (if available) |
| Last activity date | |
| Open issues | |

**Activity classification**:
- **Active**: Commits within last 6 months
- **Stale**: Last commit 6-24 months ago
- **Dormant**: Last commit > 24 months ago
- **Dead**: Empty repo or last commit > 4 years ago

**Metadata-only mode**: Use Last Commit Date and Last Activity Date. Note that Last Activity can include non-commit events (wiki edits, issue comments, settings changes).

### Step 4: Repository Content Analysis

**Deep-analysis mode** (cloned locally):

- **Primary language / technology stack**
- **README presence and quality**
- **License file**
- **Folder structure overview** (top-level directories)
- **Repo size** (code vs. artifacts vs. binary blobs)
- **Large files** (LFS usage, binaries in history)

**Metadata-only mode** (not cloned):

- **Repo size** from metadata (Repository Size field)
- **Infer type from name and namespace**: e.g., `*-docs` → documentation, `*-scripts` → script library, `*-api` → API service
- **Infer language from namespace patterns**: e.g., `python_integration/` → Python
- Note: "Content details unavailable - metadata-only analysis. Clone for deeper inspection."

### Step 5: CI/CD & Pipeline Analysis

Check for CI/CD configuration:

**Deep-analysis mode** - Parse `.gitlab-ci.yml` and summarize:
  - Stages defined
  - Jobs and their purpose
  - Runners/tags used (shared, specific)
  - Artifacts produced
  - Deployment targets
  - Environment variables / secrets referenced
  - Docker images used
  - External service integrations

**Both modes** - From metadata:
- **Has Pipeline** (Yes/No from metadata)
- **Builds Enabled** (Yes/No)
- **Job Artifacts size** (from metadata)
- **Container registry usage** (from metadata)
- **Package registry usage** (NuGet, npm, etc.)

**Azure DevOps pipeline translation estimate**:

| Complexity | Criteria | Estimated Effort |
|------------|----------|-----------------|
| Simple | No pipeline, just git mirror | < 1 hour |
| Moderate | Standard build/test pipeline, straightforward conversion | 2-4 hours |
| Complex | Custom runners, environment-specific deploys, secrets, Docker | 1-2 days |
| Very Complex | Multi-stage, cross-repo dependencies, custom tooling, container registry | 3-5 days |

### Step 6: Branch & Protection Analysis

- **Default branch** (master vs main)
- **Protected branches** listed
- **Branch count** (if available)
- **Tag count** and tag naming conventions
- **Merge request settings** (approvals, etc.)

### Step 7: Documentation & Docs-Site Usage

- Is this repo a **documentation source** for a docs site (DocFX, MkDocs, etc.)?
- Cross-reference with docs-site mapping if provided:
  - Used in DEV docs site?
  - Used in PROD docs site?
- Contains `.docfx.json`, `mkdocs.yml`, `toc.yml`, or similar? (deep-analysis mode)
- Has wiki content?

### Step 8: Dependencies & Integration Points

- References to other GitLab repos (submodules, CI includes)
- External service connections (APIs, databases, cloud services)
- NuGet/npm/pip packages produced or consumed
- Git submodules or nested projects

### Step 9: Security & Secrets Scan

Flag potential concerns:

- CI/CD variables / secrets that need migration
- `.env` files or hardcoded credentials (deep-analysis mode: quick scan)
- Deploy keys or service accounts
- Webhook configurations
- Access tokens referenced in pipeline

### Step 10: Value & Risk Assessment

Synthesize all findings into a value judgment:

**Business Value**:
- **Critical**: Powers production systems, active development, no alternative
- **High**: Important documentation, active scripts, customer-facing
- **Medium**: Useful reference, occasional use, internal tooling
- **Low**: Personal experiments, outdated POCs, abandoned prototypes
- **None**: Empty repos, forks never modified, obsolete

**Migration Risk**:
- **Low**: Simple code repo, no CI/CD, just needs git push
- **Medium**: Has CI/CD that needs translation, some secrets
- **High**: Complex pipelines, external integrations, large artifacts
- **Critical**: Production deployments, container registry, cross-repo dependencies

**Priority Score** (for batch sorting):

```
Priority = Value_Score x Risk_Weight

Value:    Critical=5, High=4, Medium=3, Low=2, None=1
Risk:     Critical=1.5, High=1.2, Medium=1.0, Low=0.8
Priority: Higher = migrate first
```

---

## GitLab-to-Azure DevOps Mapping

Reference for where GitLab features land after migration:

| GitLab Feature | Azure DevOps Equivalent | Notes |
|---------------|------------------------|-------|
| Git Repository | Azure Repos | Direct git push, preserves full history |
| `.gitlab-ci.yml` | `azure-pipelines.yml` | Requires manual translation |
| CI/CD Variables | Variable Groups / Pipeline Variables | Recreate manually, check for secrets |
| Protected Branches | Branch Policies | Configure approvers, build validation |
| Merge Requests | Pull Requests | Similar but different API/settings |
| GitLab Pages | Azure Static Web Apps (or keep separate) | Different hosting model |
| Container Registry | Azure Container Registry (ACR) | Re-push images or rebuild |
| Package Registry | Azure Artifacts | Re-publish packages |
| Webhooks | Service Hooks / Webhooks | Recreate with new URLs |
| Deploy Keys | SSH Keys / Service Connections | Recreate per-repo |
| Wiki | Azure DevOps Wiki or repo-based wiki | Export/import manually |
| Issues | Azure Boards Work Items | Optional migration, different model |
| Labels | Tags on Work Items | Manual mapping |

---

## Expected Output

Generate a structured report in this format:

```markdown
# Migration Decision Report: [REPO_NAME]

**Generated**: [DATE]
**Analyst**: AI-assisted analysis
**Status**: DRAFT - requires human review
**Analysis Mode**: Metadata-only / Deep-analysis

---

## Quick Summary

| Field | Value |
|-------|-------|
| Repository | [full path] |
| Archetype | [Production Codebase / Doc Site / Script Library / etc.] |
| Owner | [name] (Active / DEPARTED / UNKNOWN) |
| Last Activity | [date] |
| Activity Status | Active / Stale / Dormant / Dead |
| Business Value | Critical / High / Medium / Low / None |
| Migration Risk | Low / Medium / High / Critical |
| Priority Score | [calculated score] |
| Has CI/CD | Yes / No |
| Repo Size | [size] |
| Artifacts Size | [size] |
| **Recommendation** | **MIGRATE / ARCHIVE / ABANDON** |

---

## Recommendation

### Verdict: [MIGRATE / ARCHIVE / ABANDON]

**Reasoning**: [2-3 sentences explaining the decision]

**Action items**:
1. [Specific next step]
2. [Specific next step]
3. [Specific next step]

### Migration Complexity: [Simple / Moderate / Complex / Very Complex]

**Estimated effort**: [hours/days estimate]

---

## Detailed Analysis

### Ownership & People
[Findings from Step 2]

### Activity Timeline
[Findings from Step 3]

### Content Overview
[Findings from Step 4]

### CI/CD Configuration
[Findings from Step 5]

### Branch & Protection
[Findings from Step 6]

### Documentation Site Usage
[Findings from Step 7]

### Dependencies & Integrations
[Findings from Step 8]

### Security Considerations
[Findings from Step 9]

---

## Migration Checklist

### For MIGRATE verdict:
- [ ] Repository cloned and pushed to Azure Repos
- [ ] CI/CD pipeline translated to Azure Pipelines YAML
- [ ] Secrets/variables migrated to Azure DevOps variable groups
- [ ] Branch policies recreated in Azure DevOps
- [ ] Protected branches configured
- [ ] Webhooks/integrations reconnected
- [ ] Team permissions configured
- [ ] Build verified in Azure DevOps
- [ ] Old GitLab repo archived/deprecated
- [ ] Documentation updated with new URLs

### For ARCHIVE verdict:
- [ ] Repository imported to Azure Repos (read-only)
- [ ] README updated noting archived status and original GitLab URL
- [ ] Old GitLab repo marked as archived
- [ ] No CI/CD setup needed

### For ABANDON verdict:
- [ ] Decision documented with reasoning
- [ ] Old GitLab repo marked as archived (not deleted, for audit trail)
- [ ] Owner notified (if still employed)

---

## Flags & Warnings

[List any OWNER_DEPARTED, security concerns, large artifacts,
 doc-site dependencies, cross-repo references, etc.]
```

---

## Examples (Few-Shot)

### Example 1: Active documentation repo (MIGRATE)

**Input metadata**:
```
Project ID: 52 | Project Name: EBASE Supply | Path: e21-docs/ebase-supply-docs | Owner: (group) | Default Branch: master | Commits: 1317 | Last Committer: Sadaf Shoohanizad | Last Commit: 2025-12-16 | Repo Size: 3.38 MB | Artifacts: 1.62 MB | Has Pipeline: Yes | Protected Branches: master, acceptance | Archived: No | Visibility: public | Docs-site: DEV + PROD
```

**Quick Summary**:

| Field | Value |
|-------|-------|
| Repository | e21-docs/ebase-supply-docs |
| Archetype | Documentation Site |
| Owner | (group - e21-docs) Active |
| Last Activity | 2026-01-26 |
| Activity Status | Active |
| Business Value | Critical |
| Migration Risk | Medium |
| Priority Score | 5.0 |
| Has CI/CD | Yes |
| Repo Size | 3.38 MB |
| Artifacts Size | 1.62 MB |
| **Recommendation** | **MIGRATE** |

**Verdict**: **MIGRATE** - Active documentation repo with 1317 commits and recent activity (Dec 2025). Powers both DEV and PROD doc sites, making it business-critical. Pipeline builds documentation and needs translation to Azure Pipelines. Protected branches (master, acceptance) need Azure DevOps branch policies. Moderate complexity due to pipeline and docs-site integration.

### Example 2: Departed employee's personal project (ABANDON)

**Input metadata**:
```
Project ID: 108 | Project Name: EBASE JSON | Path: adam.alverback/ebase-json | Owner: Adam Alverback | Default Branch: master | Commits: 1 | Last Committer: Adam Alverback | Last Commit: 2020-02-11 | Repo Size: 0.58 MB | Artifacts: 0 MB | Has Pipeline: No | Protected Branches: master | Archived: No | Visibility: internal
Employee status: DEPARTED
```

**Quick Summary**:

| Field | Value |
|-------|-------|
| Repository | adam.alverback/ebase-json |
| Archetype | Departed Employee Project |
| Owner | Adam Alverback (DEPARTED) |
| Last Activity | 2020-02-11 |
| Activity Status | Dead |
| Business Value | None |
| Migration Risk | Low |
| Priority Score | 0.8 |
| Has CI/CD | No |
| Repo Size | 0.58 MB |
| Artifacts Size | 0 MB |
| **Recommendation** | **ABANDON** |

**Verdict**: **ABANDON** - Single commit from 2020 by departed employee in personal namespace. No pipeline, no activity for 6 years, no group dependency. No business value. Mark as archived in GitLab, do not migrate.

### Example 3: Stale but valuable production scripts (MIGRATE)

**Input metadata**:
```
Project ID: 188 | Project Name: AXPO scripts | Path: axpo1/axpo-scripts | Owner: (group) | Default Branch: main | Commits: 403 | Last Committer: Peter van der Windt | Last Commit: 2024-02-14 | Repo Size: 6.61 MB | Artifacts: 0 MB | Has Pipeline: No | Protected Branches: main, Acceptance, Test, Development | Last Activity: 2026-01-26 | Visibility: private
```

**Quick Summary**:

| Field | Value |
|-------|-------|
| Repository | axpo1/axpo-scripts |
| Archetype | Script Library |
| Owner | (group - axpo1) Active |
| Last Activity | 2026-01-26 |
| Activity Status | Stale (last commit 2024-02) |
| Business Value | High |
| Migration Risk | Low |
| Priority Score | 3.2 |
| Has CI/CD | No |
| Repo Size | 6.61 MB |
| Artifacts Size | 0 MB |
| **Recommendation** | **MIGRATE** |

**Verdict**: **MIGRATE** - 403 commits with structured branch strategy (main/Acceptance/Test/Development) strongly suggests production use with promotion workflow. Recent project activity (Jan 2026) despite last commit being Feb 2024 indicates the scripts are still being used or referenced. Private visibility indicates sensitive/customer content. Simple migration complexity (no pipeline to translate). Confirm with AXPO team that scripts are still in use.

### Example 4: Empty placeholder repo (ABANDON)

**Input metadata**:
```
Project ID: 179 | Project Name: Documentation | Path: alloc2/documentation | Owner: (group) | Default Branch: main | Commits: 0 | Last Committer: N/A | Repo Size: 0 MB | Has Pipeline: No | Empty Repo: Yes | Archived: No
```

**Quick Summary**:

| Field | Value |
|-------|-------|
| Repository | alloc2/documentation |
| Archetype | Empty Shell |
| Activity Status | Dead |
| Business Value | None |
| **Recommendation** | **ABANDON** |

**Verdict**: **ABANDON** - Empty repository with zero commits. Placeholder that was never used. Archive in GitLab, do not migrate.

### Example 5: Large platform repo with massive artifacts (MIGRATE - complex)

**Input metadata**:
```
Project ID: 98 | Project Name: EBASE Platform | Path: ebase-core/ebase-platform | Owner: (group) | Default Branch: master | Commits: 2969 | Last Committer: John van der Pol | Last Commit: 2025-12-23 | Repo Size: 469.01 MB | Artifacts: 253.62 GB | Has Pipeline: Yes | Protected Branches: master | Open Issues: 5 | Last Activity: 2026-02-16 | Visibility: internal
```

**Quick Summary**:

| Field | Value |
|-------|-------|
| Repository | ebase-core/ebase-platform |
| Archetype | Production Codebase |
| Owner | (group - ebase-core) Active |
| Last Activity | 2026-02-16 |
| Activity Status | Active |
| Business Value | Critical |
| Migration Risk | Critical |
| Priority Score | 7.5 |
| Has CI/CD | Yes |
| Repo Size | 469 MB |
| Artifacts Size | **253.62 GB** |
| **Recommendation** | **MIGRATE** |

**Verdict**: **MIGRATE** - Core platform repo, most active in the entire GitLab instance (2969 commits, activity yesterday). Business-critical. **Warning**: 253 GB of job artifacts -- do NOT migrate artifacts; rebuild in Azure Pipelines. 469 MB repo size suggests large binaries in history; consider `git filter-repo` or shallow clone. Very Complex migration due to massive size, active CI/CD pipeline, and likely extensive variable/secret configuration. Migrate first, as other repos may depend on it.

**Flags**:
- `LARGE_ARTIFACTS`: 253 GB job artifacts (do not migrate, rebuild)
- `LARGE_REPO`: 469 MB (check for binaries in git history)
- `ACTIVE_PIPELINE`: Needs careful CI/CD translation with zero-downtime cutover plan

---

## Batch Mode

When analyzing multiple repositories at once, produce a **summary table** first, sorted by Priority Score descending:

```markdown
## Migration Triage Summary

**Total repos analyzed**: [N]
**Verdicts**: MIGRATE: [n] | ARCHIVE: [n] | ABANDON: [n]
**Estimated total effort**: [X] person-days

| # | Repository | Archetype | Owner Status | Activity | Value | Risk | Priority | Verdict | Effort |
|---|-----------|-----------|-------------|----------|-------|------|----------|---------|--------|
| 1 | ebase-core/ebase-platform | Production | Active | Active | Critical | Critical | 7.5 | MIGRATE | 5d |
| 2 | e21-docs/ebase-supply-docs | Doc Site | Active | Active | Critical | Medium | 5.0 | MIGRATE | 4h |
| 3 | axpo1/axpo-scripts | Scripts | Active | Stale | High | Low | 3.2 | MIGRATE | 1h |
| 4 | blueprints/general | Blueprint | Active | Dormant | Medium | Low | 2.4 | ARCHIVE | 30m |
| 5 | adam.alverback/ebase-json | Personal | DEPARTED | Dead | None | Low | 0.8 | ABANDON | - |
| 6 | alloc2/documentation | Empty | - | Dead | None | Low | 0.8 | ABANDON | - |
```

Then provide individual detailed reports for repos marked MIGRATE or flagged for review.

---

## Troubleshooting

**Issue**: Employee roster not available -- cannot determine DEPARTED status  
**Solution**: Flag all personal-namespace repos (`username/repo`) as "Employee status: UNKNOWN - verify manually". Focus analysis on group-owned repos first. Request HR/IT to provide a list of current employees.

**Issue**: Metadata CSV has zero branches/tags (as in the provided export)  
**Solution**: Branch/tag counts may not export correctly via GitLab API depending on version. Use Protected Branches field and Default Branch as proxy. For accurate counts, clone the repo and run `git branch -a | wc -l`.

**Issue**: Large artifacts size (>10 GB) flagged  
**Solution**: Job artifacts should generally NOT be migrated -- they can be rebuilt by the CI/CD pipeline in Azure DevOps. Only migrate artifacts if they contain unique, non-reproducible data. Document this decision in the report.

**Issue**: Repo appears in both personal namespace AND group namespace (fork)  
**Solution**: Check if the personal copy has unique commits not in the group repo. If identical or behind, verdict is ABANDON for the personal fork. If ahead, merge changes back to group repo first, then ABANDON the fork.

**Issue**: Cannot determine if repo powers production systems  
**Solution**: Look for signals: private visibility + protected branches + CI/CD pipeline + client/customer namespace = likely production. Flag as "Assumed production - verify with team" and recommend MIGRATE with team confirmation.

---

## Usage

Basic single-repo analysis:
```
@analyze-gitlab-repo [paste repo metadata row]
```

With employee roster context:
```
@analyze-gitlab-repo [repo metadata]
Current employees: Alice, Bob, Charlie
Departed: Adam, Nicola, Sandro, Vincent
```

Batch analysis:
```
@analyze-gitlab-repo
Please analyze these repos for migration:
[paste multiple metadata rows]
```

Against cloned repo:
```
@analyze-gitlab-repo C:\repos\ebase-platform
```

With doc-site mapping:
```
@analyze-gitlab-repo [repo metadata]
Doc-site repos (DEV): e21-docs/ebase-supply-docs, ebase-core/nosql-timeseries-engine
Doc-site repos (PROD): e21-docs/ebase-supply-docs, scholt/scholt-docs
```

---

## Quality Criteria

- [ ] All 10 analysis steps addressed (or noted as unavailable in metadata-only mode)
- [ ] Repository archetype identified
- [ ] Clear MIGRATE / ARCHIVE / ABANDON verdict with reasoning
- [ ] Ownership status verified (Active / DEPARTED / UNKNOWN)
- [ ] CI/CD complexity assessed with Azure DevOps translation estimate
- [ ] Business value and migration risk rated
- [ ] Priority score calculated
- [ ] Security concerns flagged
- [ ] Documentation site usage cross-referenced
- [ ] Verdict-appropriate checklist included (not generic)
- [ ] Actionable next steps provided
- [ ] Report is suitable for stakeholder review
- [ ] Flags and warnings section populated

---

## Related Prompts

- `migration/analyze-cpp-component.prompt.md` - Deep analysis of C++ components for code migration
- `git/create-branch.prompt.md` - Creating branches in the target Azure DevOps repos
- `git/create-merge-request.prompt.md` - Creating PRs after migration

---

## Related Rules

- `.cursor/rules/git/branching-strategy-overview.mdc` - Branch strategy standards (useful for evaluating source repos)

---

**Created**: 2026-02-17  
**Improved**: 2026-02-17 (improve-prompt + enhance-prompt applied)  
**Follows**: `.cursor/rules/prompts/prompt-creation-rule.mdc` v1.0.0
