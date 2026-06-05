---
id: prompt.library.readme.v1
kind: documentation
version: 1.0.0
description: Documentation for Cursor Prompts Library
provenance:
  owner: team-prompts
  last_review: 2025-12-06
---

# Cursor Prompts Library

This folder contains ready-to-use, advanced prompts organized by rule category. Simply drag these prompts into your conversation with Cursor to execute common tasks efficiently.

## Structure

The prompts are organized to mirror the `.cursor/rules/` structure:

- **agile/** - Prompts for creating and managing agile artifacts
- **code-quality/** - Prompts for code review, refactoring, and quality checks
- **database-standards/** - Prompts for SQL development and database work
- **documentation/** - Prompts for generating and validating documentation
- **git/** - Prompts for Git operations and branch management
- **migration/** - Prompts for C++ to C# migration tasks
- **rule-authoring/** - Prompts for creating and maintaining rules
- **technical-specifications/** - Prompts for technical documentation
- **ticket/** - Prompts for ticket management and workflow
- **unit-testing/** - Prompts for test creation and coverage analysis

## Usage

1. **Drag & Drop**: Simply drag a `.md` file from this folder into your Cursor chat
2. **Copy & Paste**: Open a prompt file and copy its contents into the chat
3. **Reference**: Use as templates to create your own custom prompts

## Prompt Naming Convention

Prompts follow this pattern:
- `check-*.md` - Analysis and validation prompts
- `create-*.md` - Generation prompts
- `validate-*.md` - Compliance and verification prompts
- `refactor-*.md` - Improvement and restructuring prompts
- `generate-*.md` - Documentation and artifact generation

## Best Practices

- Review and customize prompts before use if needed
- Prompts are designed to work with the corresponding rule sets
- Some prompts may require file/folder paths - update them before use
- Advanced prompts include context gathering and validation steps

## Contributing

When creating new prompts:
1. Place them in the appropriate category folder
2. Use clear, descriptive filenames
3. Include all necessary context and instructions
4. Follow the prompt structure pattern in existing files

