---
name: generate-autofix-roadmap
description: "Generate an auto-fix roadmap (roadmap.md is primary, tracker.md is supporting) from a diagnostics export"
category: code-quality
argument-hint: "Ticket root path + diagnostics export path (e.g., tickets/EPP-192/EPP-192-CODEQUALITY + data/run1/output.log)"
tags: code-quality, roadmap, tracker, diagnostics, autofix, automation
---

## Generate Auto-Fix Roadmap (code-quality)

Please generate an **auto-fix roadmap** for a code-quality ticket folder based on a diagnostics export (tab-delimited).

**Primary deliverable**: `roadmap.md`  
**Supporting tool**: `tracker.md`

### Constraints
- Do **not** run builds or tests.
- Do **not** assume fixes happened unless there is **evidence** (report artifacts).

### Required Context

```xml
<inputs>
  <ticketRoot>[TICKET_ROOT]</ticketRoot>
  <runId>[RUN_ID]</runId>
  <diagnosticsExport>[DIAGNOSTICS_TSV_PATH]</diagnosticsExport>
  <scriptsRoot>[SCRIPTS_ROOT]</scriptsRoot>
</inputs>
```

**Defaults**
- `[SCRIPTS_ROOT]`: `eneve.ebase.foundation/.cursor/scripts/quality`
- Evidence reports folder: `[SCRIPTS_ROOT]/out`

### Process

1. **Parse diagnostics export**
   - Treat `[DIAGNOSTICS_TSV_PATH]` as a TSV (tab-delimited).
   - Compute:
     - Total open rows
     - Distinct diagnostic codes
     - Per-code open counts (sorted descending)

2. **Map codes to ticket subfolders**
   - Under `[TICKET_ROOT]`, locate folders matching `*-<CODE>-*`.

3. **Map codes to existing fix scripts**
   - Under `[SCRIPTS_ROOT]`, locate fix scripts `fix-*.ps1`.
   - For each code:
     - If there is an obvious match (e.g., `fix-ide0090-...` for `IDE0090`), link it.
     - If no script exists, mark as “(none yet)”.

4. **Collect evidence-based fixed counts (no guessing)**
   - Scan `[SCRIPTS_ROOT]/out` for report artifacts.
   - Only report “Fixed (evidence)” when a report exists.
   - If report format supports it (JSON with `AppliedCount`), compute:
     - Latest report file name
     - Total applied count (sum)
     - Locations (count of items)
   - Otherwise leave fixed count blank/unknown.

5. **Assess feasibility for automation**
   - For each code classify:
     - **High**: safe, local, deterministic transformation likely (good for scripting)
     - **Medium**: possible but needs guardrails / can affect APIs
     - **Low**: semantic refactor or broad ripple effects
   - Recommendation:
     - **Automate** (script-first) vs **AI-only** (manual/agent-driven)

6. **Write outputs**
   - Create/update in `[TICKET_ROOT]`:
     - `roadmap.md` (**primary**): prioritized phases (P0/P1/P2/AI-only) driven by count and feasibility
     - `tracker.md` (**supporting**): count-sorted table + evidence section + run baseline
   - Update `[TICKET_ROOT]/CATALOG.md` to link `tracker.md` and `roadmap.md` if present.

### Output Requirements

**`roadmap.md` must include**
- Run baseline (runId, totals, source file)
- Priority buckets (P0/P1/P2/AI-only)
- Ordered by count within each bucket
- For each high-priority category:
  - ticket folder link (if present)
  - existing fix script link (if present)
  - recommendation: Automate vs AI-only

**`tracker.md` must include**
- Run baseline (runId, totals, source file)
- Evidence-based “fixed” section (no guessing)
- Table sorted by open count, with columns:
  - Code
  - Open (run)
  - Sub-ticket folder
  - Fix script (existing)
  - Fixed (evidence)
  - Feasibility
  - Recommendation

### Validation
- [ ] No builds executed
- [ ] No tests executed
- [ ] Open counts derived from TSV (not manual)
- [ ] “Fixed” numbers only included when report evidence exists
- [ ] Roadmap is the primary output and is count/feasibility ordered
- [ ] Tracker is count-sorted and supports roadmap decisions


