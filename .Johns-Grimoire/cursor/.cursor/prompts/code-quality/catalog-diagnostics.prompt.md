---
name: catalog-diagnostics
description: "Catalog a tab-delimited diagnostics export into per-code extracts and optional ticket subfolders (no build/test)"
category: code-quality
argument-hint: "Input diagnostics TSV path and optional ticket root/prefix"
tags: code-quality, diagnostics, catalog, automation, no-build
---

## Catalog Diagnostics (no build/test)

Please create a repeatable workflow for cataloging diagnostics output into **per-category (per Code) extracts** and optional **ticket subfolders**.

### Constraints
- **Do not build**
- **Do not run tests**
- Focus is **cataloging + tooling**, not fixing code in this prompt.

### Required Context

```xml
<catalog>
  <inputPath>[INPUT_TSV_PATH]</inputPath>
  <runId>[RUN_ID]</runId>
  <mode>[summary|by-code|tickets]</mode>
  <ticketRoot>[TICKET_ROOT]</ticketRoot> <!-- required only when mode=tickets -->
  <ticketPrefix>[TICKET_PREFIX]</ticketPrefix> <!-- required only when mode=tickets -->
</catalog>
```

### Process
1. Validate the input is **tab-delimited** and contains columns: `Code`, `Description`, `File`, `Line`.
2. Run the catalog script:
   - Script: `eneve.ebase.foundation/.cursor/scripts/quality/catalog-diagnostics.ps1`
3. Produce:
   - Code counts (console summary)
   - Per-code extracts:
     - **tickets mode**: created under each ticket folder `data/[RUN_ID]/diagnostics.<CODE>.<RUN_ID>.tsv`
     - **by-code mode**: created under `by-code/[RUN_ID]/`
4. If mode is `tickets`, ensure each generated ticket folder has a stub `plan.md` that:
   - Restates **no build/test**
   - Points to the per-code TSV extract
   - Instructs the next agent to implement a **location-aware fixer script**

### Command Examples

**Summary only**
```powershell
pwsh -NoProfile -File eneve.ebase.foundation/.cursor/scripts/quality/catalog-diagnostics.ps1 `
  -InputPath "[INPUT_TSV_PATH]" `
  -RunId "[RUN_ID]" `
  -SummaryOnly
```

**Create ticket subfolders + per-code extracts**
```powershell
pwsh -NoProfile -File eneve.ebase.foundation/.cursor/scripts/quality/catalog-diagnostics.ps1 `
  -InputPath "[INPUT_TSV_PATH]" `
  -RunId "[RUN_ID]" `
  -CreateTicketFolders `
  -TicketRoot "[TICKET_ROOT]" `
  -TicketPrefix "[TICKET_PREFIX]"
```

### Validation
- [ ] No build commands executed
- [ ] No test commands executed
- [ ] Code counts printed
- [ ] Per-code TSV extracts written
- [ ] When mode=tickets: ticket folders created with `data/[RUN_ID]/` and `plan.md`


