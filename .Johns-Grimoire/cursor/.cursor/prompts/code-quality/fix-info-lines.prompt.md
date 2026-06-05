---
name: fix-info-lines
description: "Please fix analyzer info diagnostics (CA1062, CA1307, CA1848, IDE0060) in the provided files without suppressions"
category: code-quality
tags: diagnostics, analyzers, ca1062, ca1307, ca1848, ide0060
argument-hint: "File or folder paths containing the diagnostics"
rules:
  - .cursor/rules/prompts/prompt-creation-rule.mdc
---

# Fix Info Diagnostics

Please fix analyzer “info” diagnostics that our CI treats as build blockers. Work only on the files provided in context and apply the specific fixes below. Do not suppress diagnostics.

## Purpose
- Resolve CA1062, CA1307, CA1848, and IDE0060 diagnostics at info severity.
- Keep behavior unchanged and avoid new warnings or errors.
- Produce minimal, targeted diffs.

## Required Context
- Paths to files that contain the diagnostics.
- Current diagnostic messages (if available) for CA1062/CA1307/CA1848/IDE0060.
- Applicable logging/event ID conventions for the target code (reuse existing IDs).

## Target Diagnostics
- **CA1062**: Add argument null checks for externally visible methods before dereferencing parameters.
- **CA1307**: Use string comparison overloads that take `StringComparison` (e.g., `StringComparison.Ordinal` or `StringComparison.OrdinalIgnoreCase`).
- **CA1848**: Replace direct logger calls with cached `LoggerMessage` delegates.
- **IDE0060**: Remove unused parameters or rename them to discards (`_`, `_1`, ...).

## Fix Patterns
- **CA1062**: Guard reference parameters at method entry before any dereference.
  ```csharp
  ArgumentNullException.ThrowIfNull(options);
  ArgumentException.ThrowIfNullOrWhiteSpace(filePath);
  ```
- **CA1307**: Add explicit `StringComparison`.
  - `name.EndsWith("Id")` → `name.EndsWith("Id", StringComparison.OrdinalIgnoreCase)`
  - `string.Equals(a, b)` → `string.Equals(a, b, StringComparison.Ordinal)`
- **CA1848**: Define cached `LoggerMessage` delegates and use them.
  ```csharp
  private static readonly Action<ILogger, string, Exception?> ImportStart =
      LoggerMessage.Define<string>(LogLevel.Information, new EventId(1001, "ImportStart"),
          "Starting JSON import from {FilePath}");

  // usage
  Log.ImportStart(_logger, filePath, null);
  ```
  - Place the static `Log` class near the top of the file.
  - Reuse stable event IDs grouped by feature.
- **IDE0060**: If a parameter is unused, rename it to `_` (or `_1`, `_2`). If it should be used, wire it into the logic instead of discarding.

## Process
1. **Scan** the provided files for the four target diagnostics. Do not edit files outside the provided scope.
2. **Apply fixes** using the patterns above, keeping behavior unchanged and avoiding suppressions.
3. **Validate** locally with  
   `dotnet format analyzers --severity info --include <paths>`  
   to confirm zero remaining info diagnostics.
4. **Report** a short summary of changes and any remaining concerns.

## Expected Output
- Fixed code implementing the required patterns.
- Confirmation that `dotnet format analyzers --severity info` passes (or a list of remaining blockers with reasons).
- Brief change summary per file touched.

## Quality Checklist
- [ ] CA1062: Null guards added before dereference for externally visible reference parameters.
- [ ] CA1307: All relevant comparisons specify `StringComparison`.
- [ ] CA1848: LoggerMessage delegates defined and reused; event IDs stable.
- [ ] IDE0060: Unused parameters converted to discards or properly used.
- [ ] No suppressions added; behavior preserved.
- [ ] `dotnet format analyzers --severity info` passes for included paths.

## Usage
```
@fix-info-lines src/Services/ImportService.cs
```
