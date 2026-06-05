# Quality Scripts (`.cursor/scripts/quality`)

PowerShell utilities for enforcing and incrementally improving .NET code quality. This folder contains:
- **Orchestration scripts** (run end-to-end workflows)
- **Targeted fix scripts** (address specific diagnostic codes)
- **Shared modules** (common output + diagnostic parsing helpers)

## Requirements

- PowerShell **7.2+** (scripts are `#Requires -Version 7.2` / `#Requires -PSEdition Core`)
- .NET SDK installed (some scripts run `dotnet build`, `dotnet test`, `dotnet format`)

## Quick Start

From repository root:

```powershell
# Full pre-merge workflow (auto-fix -> build -> test -> verify formatting)
pwsh -NoProfile -File .cursor/scripts/quality/validate-pre-merge.ps1

# Dry run (show steps without changing files)
pwsh -NoProfile -File .cursor/scripts/quality/validate-pre-merge.ps1 -DryRun

# Focus on specific diagnostics in build output reporting
pwsh -NoProfile -File .cursor/scripts/quality/validate-pre-merge.ps1 -DiagnosticFilter "CS1591,IDE1006"
```

## How the scripts fit together

### `validate-pre-merge.ps1` (main orchestrator)

Primary entrypoint for “ready to merge” validation. It coordinates:
- `dotnet format` and `dotnet format analyzers` (auto-fix)
- targeted fix scripts for specific diagnostics (when present)
- `dotnet build` (warnings-as-errors)
- `dotnet test`
- `dotnet format --verify-no-changes`
- optional analyzer enablement (`enable-analyzer.ps1`) and progress tracking (`track-analyzer-progress.ps1`)

Useful flags:
- `-Steps "1-7"` / `-Steps "1,3,5"`: run selected steps
- `-DiagnosticFilter "CS1591,IDE1006"`: narrow reporting and fix selection
- `-MaxFiles`, `-MaxOutputLines`: limit output volume for batch/AI workflows
- `-JsonOutput`: machine-readable summary (for automation)
- `-ShowProgress`: show analyzer enablement progress report

### `enforce-quality.ps1` (configuration-driven enforcement)

Updates project configuration using `quality-config.json`, typically to:
- enforce warnings-as-errors
- update `.editorconfig` severities from config

Primary inputs:
- `quality-config.json`

### `build-and-find-errors.ps1` (discovery / triage)

Builds the solution and prints the first N errors (optionally filtered by diagnostic code) in a “fix-friendly” format.

### `enable-analyzer.ps1` + `track-analyzer-progress.ps1` (incremental enablement)

Used to enable analyzers gradually and track progress across runs:

```powershell
pwsh -NoProfile -File .cursor/scripts/quality/enable-analyzer.ps1 -AnalyzerId CA1062 -Severity warning
pwsh -NoProfile -File .cursor/scripts/quality/track-analyzer-progress.ps1 -AnalyzerId CA1062 -Status in-progress
pwsh -NoProfile -File .cursor/scripts/quality/track-analyzer-progress.ps1 -Report
```

### `catalog-diagnostics.ps1` (diagnostics cataloging; no build/test)

Catalogs a **tab-delimited diagnostics export** into per-code TSV extracts, and can optionally generate ticket-style subfolders for triage workflows.

```powershell
# Summary-only
pwsh -NoProfile -File .cursor/scripts/quality/catalog-diagnostics.ps1 `
  -InputPath "tickets/EPP-192/EPP-192-CODEQUALITY/data/run1/output.log" `
  -RunId "run1" `
  -SummaryOnly

# Create ticket-style folders + per-code extracts
pwsh -NoProfile -File .cursor/scripts/quality/catalog-diagnostics.ps1 `
  -InputPath "tickets/EPP-192/EPP-192-CODEQUALITY/data/run1/output.log" `
  -RunId "run1" `
  -CreateTicketFolders `
  -TicketRoot "tickets/EPP-192/EPP-192-CODEQUALITY" `
  -TicketPrefix "EPP-192-CODEQUALITY"
```

Config example:
- `catalog-diagnostics.config.example.json`

## Targeted fix scripts

Scripts prefixed with `fix-*.ps1` are intended to address specific diagnostic codes (often by pattern matching and scoped edits). They are typically invoked directly or orchestrated by `validate-pre-merge.ps1` (Step 2).

## Shared modules

- `modules/Common.psm1`: shared output helpers (Unicode/ASCII fallbacks), repo-root detection, consistent section formatting.
- `modules/Diagnostics.psm1`: parsing utilities for diagnostic outputs (MSBuild/VS “copy” formats) and line-range helpers.

## Outputs

Some scripts write reports under `out/` (for example, TSV/JSON reports for what was changed).

## Contribution

- Keep scripts **portable** (work locally and in CI/CD without hardcoded paths).
- Prefer **deterministic, idempotent** fixes.
- Use actionable diagnostics (WHAT/WHY/HOW) in script output.
- If a script has many parameters, provide a `*.config.example.json` and support `-ConfigFile`.


