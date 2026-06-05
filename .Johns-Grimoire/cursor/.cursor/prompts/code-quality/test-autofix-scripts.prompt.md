---
name: test-autofix-scripts
description: "Safe, repeatable workflow to test code-quality autofix scripts (dry-run → scoped apply → verify build/format/test)"
category: code-quality
tags: code-quality, autofix, scripts, testing, dotnet-format, roslyn, safety, repeatable
argument-hint: "Script path + diagnostic code + (optional) diagnostics TSV + include paths + solution path"
rules:
  - .cursor/rules/quality/zero-warnings-zero-errors-rule.mdc
  - .cursor/rules/quality/diagnostic-messages-agent-application-rule.mdc
  - .cursor/rules/scripts/core-principles-rule.mdc
  - .cursor/rules/scripts/powershell-standards-rule.mdc
---

# Test AutoFix Scripts (Safe + Repeatable)

Please help me **safely test** a code-quality autofix script in this repository.

The goal is to prove:
- the script is **safe** (no heuristic breakage / no unexpected changes),
- the script is **deterministic + idempotent** (re-running yields zero further diffs),
- the repo remains **buildable** and **format-clean**,
- the diagnostic count for the targeted code goes **down**.

---

## Required Context (XML)

```xml
<autofix_test_request>
  <repoRoot>[REPO_ROOT]</repoRoot>
  <solutionPath>[SOLUTION_PATH]</solutionPath> <!-- optional; defaults to single .sln in repo -->

  <diagnostic>
    <code>[DIAGNOSTIC_CODE]</code> <!-- e.g., IDE0009, CA2263, CA1825, IMPORTS -->
    <expectedSeverity>[info|warn|error]</expectedSeverity> <!-- optional; default is info -->
  </diagnostic>

  <script>
    <path>[FIX_SCRIPT_PATH]</path> <!-- e.g., .cursor/scripts/quality/fix-ca2263-generic-overload.ps1 -->
    <supportsDryRunFlag>[true|false]</supportsDryRunFlag> <!-- if unknown, set true and we’ll detect -->
    <dryRunFlags>[-WhatIf|-NoApplyChanges]</dryRunFlags> <!-- optional -->
  </script>

  <inputData>
    <diagnosticsTsvPath>[DIAGNOSTICS_TSV_PATH]</diagnosticsTsvPath> <!-- optional; when script is TSV-driven -->
    <runId>[RUN_ID]</runId> <!-- optional; e.g., run2 -->
  </inputData>

  <scope>
    <includePaths>[INCLUDE_PATHS]</includePaths> <!-- optional; comma-separated -->
    <maxFiles>[MAX_FILES]</maxFiles> <!-- optional -->
    <maxLines>[MAX_LINES]</maxLines> <!-- optional -->
  </scope>

  <policy>
    <allowHeuristicFallback>[true|false]</allowHeuristicFallback> <!-- default: false -->
    <runBuildAndTests>[true|false]</runBuildAndTests> <!-- default: true -->
  </policy>
</autofix_test_request>
```

---

## Hard Constraints (must follow)

- **No commits, pushes, merges, or tags.**
- Default to **dry-run / report-only** first.
- Default to **narrow scope** first (single file or small folder).
- If the script offers a risky mode (e.g., “heuristic fallback”), keep it **OFF** unless explicitly enabled.
- All commands must be **copy/paste-able** and run from `[REPO_ROOT]`.

---

## Process (do this in order)

### Step 0 — Preflight: clean baseline + safety net

1. Confirm working tree state:
   - `git status --porcelain`
2. If there are unrelated uncommitted changes, do **not** proceed. Instead:
   - stash or branch off (user decision), then restart the test.
3. Record a baseline snapshot:
   - `git diff --stat`

### Step 1 — Baseline the diagnostic (before)

Please determine a repeatable “before” signal using **one** of these (prefer the first that works):

1. **Roslyn / dotnet format (no changes)**:
   - `dotnet format "[SOLUTION_PATH]" --verify-no-changes --diagnostics [DIAGNOSTIC_CODE] --severity [info|warn|error]`
2. If the diagnostic is analyzer-only and supported:
   - `dotnet format analyzers "[SOLUTION_PATH]" --verify-no-changes --diagnostics [DIAGNOSTIC_CODE]`
3. If this repo tracks diagnostics via TSV:
   - confirm the count for `[DIAGNOSTIC_CODE]` from `[DIAGNOSTICS_TSV_PATH]` (or from `.cursor/scripts/quality/out/by-code/[RUN_ID]/` if already cataloged).

Capture the result as “BEFORE”.

### Step 2 — Dry run the fix script (no file edits)

Run the fix script in report-only mode:

- Prefer `-NoApplyChanges` (script still produces TSV/JSON reports).
- Else use `-WhatIf` (PowerShell `ShouldProcess`).

If the script supports scoping, **always** start with:
- `-Include` on a small folder, or
- `-MaxFiles 1-5`, and/or
- `-MaxLines 25-100`.

If the script consumes diagnostics TSV, pass `[DIAGNOSTICS_TSV_PATH]` and `[INCLUDE_PATHS]`.

Expected outcome:
- Script completes successfully.
- Report indicates what would be applied vs skipped.

### Step 3 — Apply in a narrow scope

Run the same script **without** dry-run flags, still narrow in scope.

Immediately after:
1. Review what changed:
   - `git diff --stat`
   - `git diff`
2. If the diff shows unexpected categories (e.g., large refactors, whitespace churn, or unrelated files), stop and adjust scope/strategy.

### Step 4 — Verify idempotency (re-run the same apply)

Re-run the exact same apply command again (same inputs + same scope).

Expected outcome:
- `git diff` should not change further (or should shrink to zero changes).
- Report should show mostly `skipped` / `already-fixed`.

### Step 5 — Verification gates (build/format/test)

If `<runBuildAndTests>true</runBuildAndTests>`:

1. Build:
   - `dotnet build "[SOLUTION_PATH]" -c Release`
2. Verify formatting / analyzer cleanliness for the targeted code:
   - `dotnet format "[SOLUTION_PATH]" --verify-no-changes --diagnostics [DIAGNOSTIC_CODE] --severity [info|warn|error]`
   - If applicable: `dotnet format "[SOLUTION_PATH]" --verify-no-changes --diagnostics IMPORTS --severity info`
3. Tests (if the repo expects them for this change):
   - `dotnet test "[SOLUTION_PATH]" -c Release`

### Step 6 — Re-baseline the diagnostic (after)

Repeat the Step 1 measurement and capture “AFTER”.

Expected outcome:
- Diagnostic count reduced (or fully eliminated in scope).
- No new errors introduced.

---

## Common Failure Modes (what to do)

- **Build fails after applying fixes**:
  - Identify the first few errors using:
    - `.cursor/scripts/quality/build-and-find-errors.ps1 -Configuration Release -MaxErrors 20`
  - Fix compilation first; do not continue applying more autofix changes.

- **dotnet format requires a build**:
  - Prefer scripts that can run with `--no-build` if available.
  - Otherwise, build first, then re-run format verification.

- **Fixer made unsafe edits**:
  - Stop immediately.
  - Undo via `git restore --source=HEAD -- [PATHS]` (or user-chosen rollback).
  - Update the script to be more conservative (skip ambiguous cases) and repeat Step 2 onward.

---

## Expected Output (what you must produce)

1. The exact commands used for:
   - baseline (before)
   - dry run
   - narrow apply
   - idempotency re-run
   - build/format/test verification
2. A short results table:
   - BEFORE vs AFTER diagnostic count (or pass/fail)
   - files changed count
   - build status, test status
3. A list of any remaining “skipped” patterns that require:
   - Roslyn-only fix,
   - script enhancement,
   - or manual handling.

---

## Validation Checklist

- [ ] Started with a clean working tree (or explicitly isolated changes)
- [ ] Dry-run executed successfully
- [ ] Apply ran only on a narrow scope initially
- [ ] `git diff` reviewed after apply
- [ ] Second apply run is idempotent (no additional diffs)
- [ ] Build succeeds (Release)
- [ ] `dotnet format --verify-no-changes` passes for the targeted diagnostic
- [ ] Tests pass (if enabled)
- [ ] AFTER measurement recorded and compared to BEFORE


