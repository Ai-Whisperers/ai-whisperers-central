---
name: create-autofix-script
description: "Please create a Roslyn-first auto-fixer script for a diagnostic (Roslyn report-only → script/regex → AI → human, checks existing scripts, conservative TSV-driven fallback)"
category: code-quality
tags: script-generation, diagnostic-fixes, automation, code-analysis, powershell, quality-scripts, autofix, tsv
argument-hint: "Diagnostic code (e.g., IDE0005, IDE0028, CA1861) + path to diagnostics TSV export + ticket folder path (checks existing scripts first)"
rules:
  - .cursor/rules/scripts/core-principles-rule.mdc
  - .cursor/rules/scripts/powershell-standards-rule.mdc
  - .cursor/rules/scripts/script-quality-levels-rule.mdc
  - .cursor/rules/quality/zero-warnings-zero-errors-rule.mdc
  - .cursor/rules/quality/diagnostic-messages-agent-application-rule.mdc
---

# Create AutoFix Script (Roslyn-First, Best Practices)

Please create a **Roslyn-first auto-fixer** PowerShell script for the diagnostic code described below.

**Pattern**: Safe Mass AutoFixer Pattern ⭐⭐⭐⭐  
**Effectiveness**: High when diagnostics are text-matchable and can be guarded with context checks  
**Use When**: You have a TSV export of diagnostics and want a conservative “fix what’s obviously safe” script

This prompt follows current best practices:
- **Roslyn preferred (report-only)**: Try `dotnet format` *without building* to auto-fix (when possible).
- **Existing script check**: Identify and propose adjustments to existing scripts before creating a new one.
- **Script/regex fallback**: Conservative TSV-driven fixes only after Roslyn cannot complete the job.
- **AI/Human final**: For cases requiring understanding beyond automation.

**Fix order**: Roslyn (report-only / no-build) → Script/Regex → AI → Human.

---

## Hard Constraints (must follow)

- **Do not commit, push, or tag.**
- **Do not build.**
- **Do not run tests.**
- **Do not auto-revert/reset files.** Only revert when explicitly instructed.
- If you need to do cleanup/reversal actions (delete temp artifacts, revert changes, etc.), **first inform** before doing it.

---

## Required Context (XML)

```xml
<fixer_request>
  <ticketId>[TICKET_ID]</ticketId> <!-- optional; e.g., EPP-192 -->
  <ticketPath>[TICKET_FOLDER_PATH]</ticketPath>
  <repoRoot>[REPO_ROOT]</repoRoot>
  <diagnostic>
    <code>[DIAGNOSTIC_CODE]</code>
    <message>[DIAGNOSTIC_MESSAGE]</message>
  </diagnostic>
  <diagnosticsTsv>[DIAGNOSTICS_TSV_PATH]</diagnosticsTsv>
  <includePaths>[INCLUDE_PATHS]</includePaths> <!-- optional; comma-separated -->
  <outputDirectory>[OUTPUT_DIRECTORY]</outputDirectory> <!-- optional; defaults to .cursor/scripts/quality/out -->
  <examples>
    <example>
      <file>[EXAMPLE_FILE_PATH]</file>
      <line>[LINE_NUMBER]</line>
      <snippet>[PASTE_THE_OFFENDING_LINE_OR_BLOCK]</snippet>
    </example>
  </examples>
</fixer_request>
```

---

## Goal

Create a new script under:
- `.cursor/scripts/quality/fix-[diagnostic]-[short-description].ps1`

The script should fix:
- **easy + safe** cases automatically (text-matchable, semantics-preserving).

And must:
- **skip** anything ambiguous / risky and record it in the report as `skipped` (or `partial`).

This is a **mass fixer**, not a "perfect fixer".

---

## Existing Script Check & Plan Proposal

**Before creating a new script:**

1. **Search for existing scripts**:
   - Look in `.cursor/scripts/quality/fix-[diagnostic]*.ps1`
   - Check if script already exists for this diagnostic

2. **If script exists**:
   - **Inform user** immediately with script path
   - **Test the existing script**:
     - Run with `-NoApplyChanges` (report-only)
     - Identify why it doesn't work (errors, incomplete fixes, edge cases)
   - **Propose adjustment plan**:
     - List specific issues found
     - Suggest targeted additions/modifications
     - Get user approval before proceeding with changes
     - Only then modify the existing script

3. **If no script exists**:
   - Proceed with creation following Roslyn-first strategy

---

## Roslyn Pre-Pass (Optional, No-Build Only)

If and only if it can be done **without building**, attempt a Roslyn pre-pass:

- Use a **report-only / safe** command first (example):
  - `dotnet format --no-build --diagnostics [DIAGNOSTIC_CODE]`
- If `dotnet format` cannot run without a build, or it doesn’t support the needed options in this repo/tooling:
  - record the result in your response (as “skipped Roslyn pre-pass”), and continue with TSV-driven script fixes.

Do not change these constraints:
- No `dotnet build`
- No `dotnet test`

---

## Process (Required)

1. **Validate inputs**
   - Confirm `[DIAGNOSTIC_CODE]`, `[DIAGNOSTICS_TSV_PATH]`, and `[REPO_ROOT]` are present.
   - Parse TSV using `ConvertFrom-Csv -Delimiter "`t"` and verify required columns exist (`Code`, `File`, `Line`).

2. **Find existing fixer (if any)**
   - Search `.cursor/scripts/quality/` for `fix-[DIAGNOSTIC_CODE]*.ps1`.
   - If found, run it with `-NoApplyChanges` and propose a minimal, targeted adjustment plan.

3. **Roslyn pre-pass (optional, no-build only)**
   - Attempt `dotnet format` *only* in a way that does not build (e.g., `--no-build`).
   - Treat this as an optimization; the script must still work when Roslyn is skipped.

3. **Script/Regex fallback** (only after Roslyn):
   - Inspect real data from TSV
   - Pick 1–2 files with multiple occurrences
   - Open source files around 2–3 representative lines to infer patterns
   - Define "safe patterns" for text-matchable, semantics-preserving fixes

4. **Implement conservatively**:
   - Prefer **line-scoped** and **context-guarded** edits
   - Use comment/string aware "split code vs comment" step
   - Process line numbers descending inside each file to avoid shifting
   - Treat duplicate diagnostics as ExpectedCount; attempt up to that many fixes

5. **Final options** (if script/regex insufficient):
   - AI-assisted fixes for complex cases
   - Human intervention for edge cases requiring understanding

---

## Required Script Capabilities

### CLI + Modes

- Must use:
  - `#!/usr/bin/env pwsh`
  - `#Requires -Version 7.2`
  - `#Requires -PSEdition Core`
  - `Set-StrictMode -Version Latest`
  - `$ErrorActionPreference = 'Stop'`
  - `[CmdletBinding(SupportsShouldProcess=$true)]`

- Must accept:
  - `-DiagnosticsTsvPath` (TSV export)
  - `-RepoRoot` (repo root)
  - `-Include` (optional include filters: file/folder paths)
  - `-OutputDirectory` (where to write reports)
  - `-MaxFiles` and `-MaxLines` (for step-by-step runs)
  - `-NoApplyChanges` (report-only; still produces reports)
  - `-SkipRoslyn` (optional; only if you implement Roslyn pre-pass)

### TSV parsing requirements

- Use:
  - `ConvertFrom-Csv -Delimiter "`t"`
- Validate required columns exist:
  - `Code`, `File`, `Line`
- Filter to the target diagnostic code.
- Normalize and group:
  - group by `File`, then group by `Line` (count duplicates).

### File handling requirements

- Read file **once** per file.
- Split lines in a deterministic way:
  - preserve original line endings (CRLF vs LF) on write
  - avoid regex `-split` surprises; use:
    - `Replace("`r`n","`n").Split("`n", None)`
- Only write a file when content changes and `-NoApplyChanges` is not set.

---

## Reporting (required deliverable)

Produce **both** TSV + JSON reports with one row/entry per (File, Line) group:

- `File`
- `Line`
- `ExpectedCount` (duplicates at that line)
- `AppliedCount`
- `Status`:
  - `fixed` | `partial` | `skipped` | `missing-file` | `line-out-of-range`
- `Applied` (pattern IDs or short names of transformations applied)
- `OriginalLine`
- `UpdatedLine`

Reports must be timestamped and written under:
- `.cursor/scripts/quality/out/` (default) or `-OutputDirectory`

---

## Expected Output (Assistant Response Format)

When you respond, include:
- The created/updated script path.
- The exact command to run in report-only mode (`-NoApplyChanges`) with realistic example arguments.
- A short list of the “safe patterns” you implemented (pattern IDs) and what each one changes.
- Any categories you intentionally skip (with a brief reason).

---

## Examples (Few-Shot)

### Example 1: New fixer from TSV

**Input**:

```xml
<fixer_request>
  <ticketId>EPP-999</ticketId>
  <ticketPath>tickets/EPP-999</ticketPath>
  <repoRoot>E:\WPG\Git\E21\GitRepos\eneve.ebase.foundation</repoRoot>
  <diagnostic>
    <code>IDE0005</code>
    <message>Using directive is unnecessary.</message>
  </diagnostic>
  <diagnosticsTsv>tickets/EPP-999/diagnostics.tsv</diagnosticsTsv>
  <includePaths>src/,tst/</includePaths>
  <examples>
    <example>
      <file>src/Foo/Bar.cs</file>
      <line>3</line>
      <snippet>using System.Linq;</snippet>
    </example>
  </examples>
</fixer_request>
```

**Expected Output**:
- Create `.cursor/scripts/quality/fix-ide0005-remove-unused-usings.ps1` (name may vary).
- Script supports `-NoApplyChanges`, `-MaxFiles`, `-MaxLines`, writes TSV+JSON to `.cursor/scripts/quality/out/`.
- If Roslyn pre-pass cannot run without build, it is skipped and noted.

### Example 2: Existing fixer found

**Input**: Same as above, but a script already exists at `.cursor/scripts/quality/fix-ide0005-*.ps1`.

**Expected Output**:
- Identify the existing script.
- Run it in `-NoApplyChanges` mode (no build, no tests).
- Propose a targeted adjustment plan (do not implement changes until approved).

---

## Validation Checklist (Must Pass)

- [ ] The prompt’s constraints are respected (no commit/push/tag, no build, no tests).
- [ ] The script path follows: `.cursor/scripts/quality/fix-[diagnostic]-[short-description].ps1`.
- [ ] TSV parsing validates required columns (`Code`, `File`, `Line`) and filters to `[DIAGNOSTIC_CODE]`.
- [ ] File writes happen only when content changes and `-NoApplyChanges` is not set.
- [ ] Reports are produced as both TSV and JSON and are timestamped.
- [ ] Ambiguous/risky cases are skipped and recorded as `skipped` or `partial`.

---

## Troubleshooting

- **Roslyn pre-pass fails because a build is required**
  - Action: Record “skipped Roslyn pre-pass (requires build)” and proceed with TSV-driven fixes.

- **TSV doesn’t contain expected columns**
  - Action: Fail fast with an error explaining which columns are missing and how to regenerate/export the TSV.

- **Line numbers don’t match file content (line-out-of-range)**
  - Action: Record `line-out-of-range` and do not attempt a guess-based fix.

---

## Output Expectations

When you respond, you must:
1. Create/update the script file in `.cursor/scripts/quality/`.
2. Ensure it runs in **report-only mode** (`-NoApplyChanges`) without errors.
3. Ensure it supports step-by-step runs (`-MaxFiles`, `-MaxLines`) for safe incremental application.


