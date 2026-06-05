---
type: exemplar
artifact-type: prompt
demonstrates: ticket-fix-plan
domain: ticket workflow
quality-score: exceptional
version: 1.0.0
illustrates: ticket.fix-plan
extracted-from: .cursor/prompts/ticket/fix-plan.prompt.md
notes: "OPSEC-sensitive sample values were redacted during extraction."
---

# Fix Plan Patterns Exemplar

## Extracted Patterns (Examples)

## Fix Patterns by Issue Type

### Pattern 1: Fix Vague Objective

**Issue**: Objective is "Fix the bug" or "Improve feature"

**Fix Strategy**:
```markdown
## Objective
[What is being built/fixed] to [achieve what outcome].

[Current situation/problem statement in 1-2 sentences].

Success looks like: [specific end state].

In scope: [what will be addressed]
Out of scope: [what won't be addressed]
```

**Example Fix**:

**Before** (vague):
```markdown
## Objective
Fix the calendar bug
```

**After** (specific):
```markdown
## Objective
Fix calendar event display bug where events are not showing for dates after January 1, 2026.

Current situation: Calendar widget displays events correctly for dates in 2025, but returns empty results for any date in 2026 or later due to a date comparison issue in the query filter. Users cannot view or manage future events.

Success looks like: All calendar events display correctly regardless of date, with proper filtering and sorting maintained.

In scope: Fix date filtering logic in calendar query, add test coverage for future dates
Out of scope: Calendar UI redesign, performance optimization
```

---

### Pattern 2: Fix Non-Actionable Requirements

**Issue**: Requirements are "Make it work", "Improve performance"

**Fix Strategy**: Ask "What specifically must be built/changed?" and enumerate concrete items.

**Example Fix**:

**Before** (vague):
```markdown
## Requirements
- Make calendar work properly
- Improve performance
```

**After** (specific):
```markdown
## Requirements
- Fix date filter in CalendarEventRepository.GetEventsByDateRange() to handle dates >= 2026
- Update SQL query WHERE clause to use >= instead of > for date comparison
- Add unit tests for edge cases: year boundary (2025-12-31 to 2026-01-01), leap years
- Ensure query performance remains <500ms for date ranges up to 1 year
- Verify calendar UI updates correctly after backend fix
```

---

### Pattern 3: Fix Non-Testable Acceptance Criteria

**Issue**: Criteria are "Works well", "Users are happy", "Performance is good"

**Fix Strategy**: Convert subjective to objective/measurable with specific pass/fail conditions.

**Example Fix**:

**Before** (subjective):
```markdown
## Acceptance Criteria
- Calendar works correctly
- Performance is good
- Users are satisfied
```

**After** (testable):
```markdown
## Acceptance Criteria
- [ ] GetEventsByDateRange returns events for dates in 2026 and beyond
- [ ] Calendar UI displays events for 2026-01-15 when date selected
- [ ] Date filter query uses >= comparison (verified in code review)
- [ ] Unit test passes: GetEventsByDateRange("2026-01-01", "2026-01-31") returns expected events
- [ ] Integration test passes: Calendar page loads with 2026 events visible
- [ ] Query execution time <500ms for 1-year date range (measured in tests)
- [ ] Zero regression: All existing calendar tests still pass
- [ ] Manual verification: Can view and interact with events through December 2030
```

---

### Pattern 4: Fix Placeholder Implementation Strategy

**Issue**: Strategy is "TBD", "Will figure it out", or empty

**Fix Strategy**: Define high-level approach with 3-5 major phases/steps.

**Example Fix**:

**Before** (placeholder):
```markdown
## Implementation Strategy
TBD - will figure it out during implementation
```

**After** (actionable):
```markdown
## Implementation Strategy

1. **Identify root cause** - Review CalendarEventRepository.GetEventsByDateRange() and locate date comparison logic in SQL query or LINQ expression

2. **Fix date filter** - Update comparison operator from > to >= (or equivalent) to include boundary dates correctly

3. **Update unit tests** - Add test cases for:
   - Events on 2026-01-01 (boundary date)
   - Events in 2026 through 2030 (future dates)
   - Year boundary crossing (2025-12-31 to 2026-01-02 range)

4. **Verify UI integration** - Test calendar widget with fixed backend to ensure events display correctly for 2026+ dates

5. **Run regression tests** - Confirm all existing calendar tests still pass, no functionality broken

6. **Performance check** - Verify query performance remains acceptable with updated filter

Files affected:
- `Infrastructure/Repositories/CalendarEventRepository.cs` (main fix)
- `Tests/CalendarEventRepositoryTests.cs` (new test cases)
- `Tests/Integration/CalendarIntegrationTests.cs` (UI integration verification)
```

---

### Pattern 5: Add Missing Complexity Assessment

**Issue**: Complexity Assessment section missing entirely

**Fix Strategy**: Evaluate using criteria (files affected, lines changed, pattern familiarity, risk) and document.

**Example Fix**:

**Before** (missing):
```markdown
[No Complexity Assessment section]
```

**After** (complete):
```markdown
## Complexity Assessment

**Track**: Simple Fix

**Rationale**: Single root cause (date comparison operator bug), affects only 1 implementation file (CalendarEventRepository.cs) and 2 test files. Change is localized to query filter logic (~5 lines). Low integration risk - date filtering is isolated concern. Pattern is familiar (standard date range query).

**Criteria Met**:
- Single root cause: Date comparison operator in query filter
- Affects 3 files total (1 implementation, 2 test files)
- Estimated ~5-10 lines changed in implementation, ~20 lines of new tests
- Low risk: Query filter change, existing tests provide regression coverage
- Familiar pattern: Standard date filtering, similar to other repository queries in codebase
```

---

### Pattern 6: Fix OPSEC Violations

**Issue**: Plan contains credentials, internal paths, server names, PII

**Fix Strategy**: Redact sensitive information, replace with generic references or vault references.

**Example Fix**:

**Before** (OPSEC violation):
```markdown
## Implementation Strategy
1. Edit `<REDACTED_PATH>`
2. Update connection string to: `Server=<REDACTED_HOST>;Database=<REDACTED_DB>;<REDACTED_CREDENTIALS>`
3. Restart IIS service on <REDACTED_SERVICE>
```

**After** (OPSEC compliant):
```markdown
## Implementation Strategy
1. Access production configuration management system
2. Update database connection string using credentials from secure vault (reference: vault://prod/calendar-db-connection)
3. Deploy updated configuration following standard deployment process
4. Restart application service following deployment runbook
```
