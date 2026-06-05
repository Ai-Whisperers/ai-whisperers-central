---
name: build-and-find-errors
description: "Build solution and show first N errors of specific type for quick fixing"
category: script
tags: [build, errors, compilation, debugging, quality]
---

# Build and Find Errors

Build the .NET solution and filter compilation errors to show the first N errors of a specific type, making it easy to fix issues systematically.

## Required Context

- **Solution Path**: The .NET solution file path (defaults to current directory)
- **Error Type**: Specific error code to filter (optional, shows all if not specified)
- **Max Errors**: Number of errors to display (default: 10)

## Process

1. **Build Solution**: Run `dotnet build` with specified configuration (Note: `TreatWarningsAsErrors=true` means warnings appear as errors)
2. **Parse Output**: Extract compilation errors from build output
3. **Filter Errors**: Show only specified error type if provided
4. **Display Results**: Format first N errors with file location and fix guidance

## Quality Configuration Context

**Production Code**:
- `TreatWarningsAsErrors=true` - All warnings become build errors
- `CA1860` globally suppressed (Any() preferred over Count() > 0)
- All other analyzers enabled at warning/error severity

**Test Projects** (`IsTestProject=true`):
- `TreatWarningsAsErrors=false` - Warnings don't block builds
- Additional suppressions: `CA1707` (underscores), `IDE1006` (naming), `CA1860` (Any usage)
- Documentation generation disabled

## Quality Enforcement Context

**Build Configuration**:
- `TreatWarningsAsErrors=true` - All warnings treated as errors in production code
- `TreatWarningsAsErrors=false` - Tests allow warnings for flexibility

**Globally Suppressed Analyzers** (via Directory.Build.props):
- `CA1860` - Any() vs Count() > 0 (suppressed globally for all code)

**Test-Only Suppressions**:
- `CA1707` - Underscores in test method names
- `IDE1006` - Naming conventions in tests
- `CA1860` - (redundant, already global)
- `CS1591` - XML documentation (via GenerateDocumentationFile=false)

## Usage Examples

### Find CS1591 (Missing XML Documentation) Errors
```powershell
.\.cursor\scripts\quality\build-and-find-errors.ps1 -ErrorType CS1591
```

### Find First 5 Compilation Errors
```powershell
.\.cursor\scripts\quality\build-and-find-errors.ps1 -MaxErrors 5
```

### Find Specific Error Type in Debug Build
```powershell
.\.cursor\scripts\quality\build-and-find-errors.ps1 -ErrorType CS0246 -Configuration Debug -MaxErrors 3
```

## Expected Output Format

```
🔍 Starting build process...
  Solution: MySolution.sln
  Configuration: Release
  Build started at: 14:30:25
  Build completed in 12.3s

Found 8 CS1591 errors. Showing first 3...

❌ 1. CS1591 Error
   File: src/MyClass.cs
   Location: Line 45, Column 12
   Message: Missing XML comment for publicly visible type or member
   Fix: Add XML documentation comment above the method
   Example: /// <summary>Adds two numbers</summary>

❌ 2. CS1591 Error
   [additional errors...]
```

## Common Error/Warning Types

**Compilation Errors (CS-series)**:
- **CS1591**: Missing XML documentation (error due to GenerateDocumentationFile=true)
- **CS0246**: Namespace/type not found
- **CS1061**: Member does not exist
- **CS0103**: Name does not exist in current context

**Analyzer Warnings (treated as errors)**:
- **CA1062**: Validate arguments of public methods
- **CA1307**: Specify StringComparison for clarity
- **CA1848**: Use LoggerMessage delegates for performance
- **IDE1006**: Naming rule violations (async methods, private fields)
- **IDE0060**: Remove unused parameters

**Note**: With `TreatWarningsAsErrors=true`, all warnings appear as build errors. CA1860 will not appear (globally suppressed).

## Quality Criteria

- [ ] Build completes and shows progress
- [ ] Errors are parsed and formatted clearly
- [ ] File paths and line numbers are accurate
- [ ] Specific fix guidance provided per error type
- [ ] Filtering works correctly by error type

---

**Save to**: `.cursor/scripts/quality/build-and-find-errors.ps1`
**Related**: `validate-script-standards.prompt.md`, `convert-to-reusable-script.prompt.md`
