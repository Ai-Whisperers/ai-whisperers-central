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

1. **Build Solution**: Run `dotnet build` with specified configuration
2. **Parse Output**: Extract compilation errors from build output
3. **Filter Errors**: Show only specified error type if provided
4. **Display Results**: Format first N errors with file location and fix guidance

## Usage Examples

### Find CS1591 (Missing XML Documentation) Errors
```
.\build-and-find-errors.ps1 -ErrorType CS1591
```

### Find First 5 Compilation Errors
```
.\build-and-find-errors.ps1 -MaxErrors 5
```

### Find Specific Error Type in Debug Build
```
.\build-and-find-errors.ps1 -ErrorType CS0246 -Configuration Debug -MaxErrors 3
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

## Error Types Supported

- **CS1591**: Missing XML documentation
- **CS0246**: Namespace/type not found
- **CS1061**: Member does not exist
- **CS0103**: Name does not exist in current context
- And many others...

## Quality Criteria

- [ ] Build completes and shows progress
- [ ] Errors are parsed and formatted clearly
- [ ] File paths and line numbers are accurate
- [ ] Specific fix guidance provided per error type
- [ ] Filtering works correctly by error type

---

**Save to**: `scripts/build-and-find-errors.ps1`
**Related**: `validate-script-standards.prompt.md`, `convert-to-reusable-script.prompt.md`







