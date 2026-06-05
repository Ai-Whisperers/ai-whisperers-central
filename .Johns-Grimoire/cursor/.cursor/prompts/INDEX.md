---
id: prompt.library.index.v1
kind: documentation
version: 1.2.0
description: Index of Cursor Prompts
provenance:
  owner: team-prompts
  last_review: 2025-12-06
---

# Prompts Index

Quick reference guide to all available prompts organized by category.

## 🛠️ Setup

| Prompt | Description | Path |
|--------|-------------|------|
| **Bootstrap New Repository** ⭐ | **Clone Gold Standard setup from eneve.domain** | `setup/bootstrap-new-repo.md` |
| Setup Repository Standards | Interactive setup for repository structure and rules | `setup/setup-repository-standards.md` |
| Setup Project Standards | Interactive setup for project-level standards | `setup/setup-project-standards.md` |

## 🚀 CI/CD

| Prompt | Description | Path |
|--------|-------------|------|
| **Implement Tag-Based CI/CD** ⭐ | **Complete tag-based versioning pipeline with RC workflow** | `cicd/implement-tag-based-cicd.md` |
| Setup Documentation Pipeline | Create complete Azure DevOps CI/CD pipeline with documentation validation | `cicd/setup-documentation-pipeline.md` |

## 📚 Documentation

| Prompt | Description | Path |
|--------|-------------|------|
| Check Folder Documentation | Analyze XML documentation coverage in a folder | `documentation/check-folder-documentation.md` |
| Generate Missing Docs | Add XML documentation to files | `documentation/generate-missing-docs.md` |
| Validate Documentation Quality | Deep quality analysis of documentation | `documentation/validate-documentation-quality.md` |

## 🧪 Unit Testing

| Prompt | Description | Path |
|--------|-------------|------|
| Check Test Coverage | Analyze unit test coverage and gaps | `unit-testing/check-test-coverage.md` |
| Generate Missing Tests | Create comprehensive unit tests | `unit-testing/generate-missing-tests.md` |
| Validate Test Quality | Assess test quality and best practices | `unit-testing/validate-test-quality.md` |

## ✨ Code Quality

| Prompt | Description | Path |
|--------|-------------|------|
| **Report Errors** ⭐ | **Pattern-based error debugging (100% diagnosis)** | `code-quality/report-errors.md` |
| **Request Feature** | **Pattern-based feature requests** | `code-quality/request-feature.md` |
| **Iterative Refinement** | **Pattern-based focused fixes** | `code-quality/iterative-refinement.md` |
| **Architectural Question** | **Pattern-based design clarification** | `code-quality/architectural-question.md` |
| Review Code Quality | Comprehensive code quality review | `code-quality/review-code-quality.md` |
| Refactor for Clean Code | Refactor code applying clean code principles | `code-quality/refactor-for-clean-code.md` |
| Check Naming Conventions | Analyze naming conventions compliance | `code-quality/check-naming-conventions.md` |

## 🎫 Ticket Management

| Prompt | Description | Path |
|--------|-------------|------|
| **Activate Ticket** ⭐ | **Pattern-based ticket activation (95% success)** | `ticket/activate-ticket.md` |
| **Resume Tracker Work** ⭐ | **Pattern-based multi-session continuation** | `ticket/resume-tracker-work.md` |
| **Validate Before Action** ⭐ | **Pattern-based validation-then-execute** | `ticket/validate-before-action.md` |
| **Check Status** | **Pattern-based status review** | `ticket/check-status.md` |
| **Catch Up on Ticket** ⭐ | **Pattern-based narrative summary (rebuilding context)** | `ticket/catchup-on-ticket.md` |
| Catalog Roadmaps | Catalog folder/ticket roadmaps and gaps | `roadmap/catalog-roadmaps.prompt.md` |
| Start Ticket | Initialize ticket with documentation | `ticket/start-ticket.md` |
| Update Progress | Update ticket progress and context | `ticket/update-progress.md` |
| Create/Update Roadmap | Create or update roadmap for tickets with subtasks | `roadmap/create-update-roadmap.prompt.md` |
| Create Tracker | Create evidence-backed task tracker | `tracker/create-tracker.prompt.md` |
| Update Tracker | Reconcile tracker with latest evidence | `tracker/update-tracker.prompt.md` |
| Validate Completion | Comprehensive completion validation | `ticket/validate-completion.md` |

## 🌿 Git Operations

| Prompt | Description | Path |
|--------|-------------|------|
| Create Branch | Create properly named Git branch | `git/create-branch.md` |
| Prepare Commit | Prepare commit with proper message | `git/prepare-commit.md` |
| Create Merge Request | Create standardized MR description | `git/create-merge-request.md` |

## 🗄️ Database Standards

| Prompt | Description | Path |
|--------|-------------|------|
| Review SQL Script | Review SQL script quality and standards | `database-standards/review-sql-script.md` |
| Create Migration Script | Create database migration script | `database-standards/create-migration-script.md` |

## 📋 Agile

| Prompt | Description | Path |
|--------|-------------|------|
| Create Epic | Create well-structured Agile Epic | `agile/create-epic.md` |
| Create Business Feature | Create well-structured Agile Business Feature | `agile/create-business-feature.md` |
| Create Technical Feature | Create well-structured Agile Technical Feature | `agile/create-technical-feature.md` |
| Create User Story | Create well-structured user story | `agile/create-user-story.md` |
| Split User Story | Split large story into smaller ones | `agile/split-user-story.md` |

## 📖 Technical Specifications

| Prompt | Description | Path |
|--------|-------------|------|
| Create Domain Overview | Create central navigation hub | `technical/create-domain-overview.md` |
| Create Business Rules | Create Business Rules specification | `technical/create-business-rules.md` |
| Create Entity Relationship | Create database schema documentation | `technical/create-entity-relationship.md` |
| Create Integration Points | Create external interface specification | `technical/create-integration-points.md` |
| Document Domain Object | Create domain object specification | `technical-specifications/document-domain-object.md` |
| Document Enumeration | Create enumeration specification | `technical-specifications/document-enumeration.md` |

## 🔄 Migration

| Prompt | Description | Path |
|--------|-------------|------|
| Analyze C++ Component | Analyze C++ component for migration | `migration/analyze-cpp-component.md` |

## 📜 Rule Authoring

| Prompt | Description | Path |
|--------|-------------|------|
| Create New Rule | Create new rule following framework | `rule-authoring/create-new-rule.md` |
| Validate Rule Compliance | Validate rule against framework standards | `rule-authoring/validate-rule-compliance.md` |

---

## 🚀 Quick Start

1. **Find the prompt** you need in the table above
2. **Navigate** to the file path shown
3. **Open** the prompt file
4. **Replace** placeholder text (marked with `[REPLACE WITH ...]`)
5. **Drag** or **paste** the prompt into Cursor chat

## 💡 Tips

- **Combine prompts**: Use multiple prompts in sequence for complex workflows
- **Customize**: Feel free to modify prompts for your specific needs
- **Feedback**: If you find issues or have suggestions, update the prompt files

## 📁 Folder Structure

```text
.cursor/prompts/
├── README.md                    # Main overview
├── INDEX.md                     # This file - quick reference
├── cicd/                        # CI/CD pipeline prompts
├── documentation/               # Documentation prompts
├── unit-testing/               # Testing prompts
├── code-quality/               # Code review prompts
├── ticket/                     # Ticket workflow prompts
├── git/                        # Git operation prompts
├── database-standards/         # SQL and database prompts
├── agile/                      # Agile artifact prompts
├── technical/                  # Spec writing prompts (new)
├── technical-specifications/   # Spec writing prompts (legacy)
├── migration/                  # Migration prompts
└── rule-authoring/            # Rule creation prompts
```

## 🔄 Updates

Last updated: 2025-12-06
Version: 1.2.0

**Recent additions:**

- ✨ Ticket: Catch Up on Ticket (narrative summary for context rebuilding)
- ✨ Agile: Epics, Business/Technical Features
- ✨ Technical: Domain Overview, Business Rules, ERD, Integration Points
- ✨ Git: Merge Request Description

Check this file regularly for new prompts!
