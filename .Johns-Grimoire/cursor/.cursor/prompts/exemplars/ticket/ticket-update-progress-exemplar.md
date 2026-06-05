---
type: exemplar
artifact-type: prompt
demonstrates: ticket-update-progress
domain: ticket workflow
quality-score: exceptional
version: 1.0.0
illustrates: ticket.update-progress
extracted-from: .cursor/prompts/ticket/update-progress.prompt.md
---

# Update Progress Exemplar

## Examples (Few-Shot)

### Example 1: Feature Implementation Session

**Input**: 
```xml
<ticket>
  <id>EBASE-12345</id>
  <action>update progress</action>
  <context>Implemented repository pattern for Market entity with CRUD operations</context>
  <session_summary>Implemented repository pattern for Market entity with CRUD operations</session_summary>
</ticket>
```

**Reasoning**:
User completed work on Market repository. AI should document specific accomplishments (MarketRepository class, mapper, async ops, UnitOfWork integration), decisions made (Dapper choice, bidirectional mapping approach), and logical next steps (unit tests, next repository).

**Expected Output**:
```markdown
## Progress Update Complete

**Ticket**: EBASE-12345
**Session**: 2025-12-08 15:30

### ✅ Progress Entry Added

New entry appended to `tickets/EBASE-12345/progress.md`:

```markdown
### 2025-12-08 15:30 - Market Repository Implementation

#### Session Summary
Implemented concrete repository for Market entity with full CRUD operations, async support, and bidirectional entity mapping.

#### Accomplished
- Created `MarketRepository` class with all CRUD methods (Create, Read, Update, Delete, GetAll)
- Implemented `MarketEntityMapper` for bidirectional conversions (domain ↔ database)
- Added async operations throughout repository (no synchronous blocking)
- Integrated with UnitOfWork pattern for transaction support

#### Decisions
- **Used Dapper for data access**: Chosen for performance and explicit control over SQL vs EF Core's abstraction overhead. Dapper gives us fine-grained query control needed for complex joins.
- **Bidirectional mapping**: Separate mapper class for maintainability vs inline conversions. Keeps repository focused on data access, mapper focused on transformations.
- **Async-first**: All operations async to align with modern .NET patterns and avoid thread pool starvation.

#### Changes
- `Markets/Repositories/MarketRepository.cs` - New file, 250 lines, full CRUD implementation
- `Markets/Mappers/MarketEntityMapper.cs` - New file, 80 lines, entity conversions (domain ↔ DB)
- `Markets/UnitOfWork/MarketsUnitOfWork.cs` - Updated to include Market repository property

#### Issues/Blockers
- None encountered this session

#### Metrics
- 1 repository implemented (1/14 complete for milestone, 7% progress)
- 100% async operations
- ~95% code coverage expected (to be verified with unit tests)

#### Next Steps
- Implement unit tests for MarketRepository (CRUD operations, edge cases)
- Implement MarketParty repository (next in Markets domain)
- Update integration tests to use new repository instead of direct ADO.NET calls
```

### 📝 Context Updated

Updated `tickets/EBASE-12345/context.md`:

**Current Technical State**:
- Market repository fully implemented and integrated with UnitOfWork
- Repository pattern established (template for remaining 13 repositories)
- Async operations confirmed throughout

**Focus Areas**:
- Unit test coverage for Market repository
- Continue Markets domain (4 repositories remaining: MarketParty, MarketRole, GridPointType, Country)

**Immediate Next Steps**:
1. Create `MarketRepositoryTests` with comprehensive test coverage
2. Implement MarketParty repository following Market pattern
3. Validate transaction behavior with UnitOfWork integration tests

### 📊 Status Assessment

- Completion: 7% (1/14 repositories complete)
- Remaining work: 13 repositories + testing
- On track: Yes - first repository establishes pattern for others (estimate 5-7 days total)

### ⏭️ Next Steps

1. Create unit tests for MarketRepository
2. Implement MarketParty repository (follow established pattern)
3. Continue systematic progress through Markets domain

**Files Updated**:
- `tickets/EBASE-12345/progress.md` - New entry appended
- `tickets/EBASE-12345/context.md` - Current state updated with Market repository completion
```

### Example 2: Bug Fix Session

**Input**:
```xml
<ticket>
  <id>EPP-192</id>
  <action>update progress</action>
  <context>Fixed memory leak in cache manager by adding explicit WeakReference cleanup</context>
  <session_summary>Fixed memory leak in cache manager by adding explicit WeakReference cleanup</session_summary>
</ticket>
```

**Reasoning**:
User resolved a memory leak. AI should document root cause, fix implementation, validation approach, and decisions made (explicit cleanup vs relying on GC).

**Expected Output**:
```markdown
## Progress Update Complete

**Ticket**: EPP-192
**Session**: 2025-12-08 10:15

### ✅ Progress Entry Added

New entry appended to `tickets/EPP-192/progress.md`:

```markdown
### 2025-12-08 10:15 - Cache Manager Memory Leak Fix

#### Session Summary
Identified and resolved memory leak caused by WeakReference instances not being properly cleared during cache eviction.

#### Accomplished
- Root cause identified: WeakReference cleanup missing in Dispose()
- Implemented explicit cleanup in CacheManager.Dispose() method
- Added defensive null checks before cleanup operations
- Verified fix with long-running memory profiler test (dotMemory, 24-hour run)

#### Decisions
- **Explicit cleanup in Dispose**: Added manual WeakReference.SetTarget(null) calls rather than relying solely on GC. Testing showed GC.SuppressFinalize() alone wasn't sufficient.
- **Defensive coding**: Added null checks before cleanup operations to handle edge cases where references might already be cleared.
- **Memory profiler validation**: Used dotMemory to confirm leak resolution vs just relying on unit tests. Visual confirmation of memory release over 24 hours.

#### Changes
- `Cache/CacheManager.cs` - Lines 145-160, added explicit cleanup in Dispose() method
- `Cache/CacheManager.cs` - Lines 78-82, added defensive null checks before WeakReference operations

#### Issues/Blockers
- **Initial fix attempt with GC.SuppressFinalize() alone didn't resolve leak**: GC wasn't collecting WeakReference targets fast enough
- **Solution**: Explicit SetTarget(null) required for immediate WeakReference cleanup, confirmed with profiler

#### Metrics
- Memory usage reduced by 40% in 24-hour stress test
- Leak eliminated (verified with dotMemory profiler - flat memory profile over time)

#### Next Steps
- Add regression test to CI pipeline (prevent future memory leaks from similar issues)
- Complete RCA document with detailed root cause analysis and prevention strategies
- Consider adding automated memory leak detection to test suite (catch similar issues earlier)
```

### 📝 Context Updated

Updated `tickets/EPP-192/context.md`:

**Current Technical State**:
- CacheManager memory leak fixed (WeakReference cleanup in Dispose)
- Fix verified with 24-hour profiler run
- Ready for RCA documentation and prevention measures

**Immediate Next Steps**:
1. Complete RCA document (root cause, fix, prevention)
2. Add regression test to CI
3. Review other WeakReference usages in codebase

### 📊 Status Assessment

- Completion: 90% (fix complete, RCA and testing remaining)
- Remaining work: RCA documentation, CI regression test
- On track: Yes - fix verified, final documentation phase

### ⏭️ Next Steps

1. Complete RCA document with detailed analysis
2. Add regression test to CI pipeline
3. Close ticket after validation

**Files Updated**:
- `tickets/EPP-192/progress.md` - New entry appended
- `tickets/EPP-192/context.md` - Current state updated with fix completion
```

### Example 3: Documentation Session

**Input**:
```xml
<ticket>
  <id>EBASE-13017</id>
  <action>update progress</action>
  <context>Added XML documentation to 10 domain entity classes achieving 100% public API coverage</context>
  <session_summary>Added XML documentation to 10 domain entity classes achieving 100% public API coverage</session_summary>
</ticket>
```

**Reasoning**:
User completed documentation work. AI should document specific files, approach taken (business-focused descriptions), and systematic progress toward overall goal.

**Expected Output**:
```markdown
## Progress Update Complete

**Ticket**: EBASE-13017
**Session**: 2025-12-08 14:00

### ✅ Progress Entry Added

New entry appended to `tickets/EBASE-13017/progress.md`:

```markdown
### 2025-12-08 14:00 - Domain XML Documentation

#### Session Summary
Completed XML documentation for 10 domain entity classes in Eneve.Domain, achieving 100% public API coverage for these entities.

#### Accomplished
- Added XML comments to 10 entity classes (Market, MarketParty, MarketRole, GridPointType, Country, MeterProduct, MeterPictogram, PhysicalProduct, Profile, ProfileClass)
- Documented all public properties with business meanings and usage context
- Included usage examples in class summaries where applicable
- Enabled GenerateDocumentationFile in Eneve.Domain.csproj project settings

#### Decisions
- **Business-focused descriptions**: Emphasized business meaning and purpose over technical details for domain entities. Helps non-technical stakeholders understand domain model.
- **Examples in summaries**: Included real-world usage examples where helpful (e.g., MarketParty creation scenarios) to aid understanding.
- **Complete coverage**: Documented private/internal members as well for maintainability, even though not required for public API docs.

#### Changes
- `Domain/Entities/Market.cs` - Added XML docs (45 lines covering class, 8 properties)
- `Domain/Entities/MarketParty.cs` - Added XML docs (38 lines)
- `Domain/Entities/MarketRole.cs` - Added XML docs (25 lines)
- `Domain/Entities/GridPointType.cs` - Added XML docs (30 lines)
- `Domain/Entities/Country.cs` - Added XML docs (28 lines)
- `Domain/Entities/MeterProduct.cs` - Added XML docs (42 lines)
- `Domain/Entities/MeterPictogram.cs` - Added XML docs (20 lines)
- `Domain/Entities/PhysicalProduct.cs` - Added XML docs (35 lines)
- `Domain/Entities/Profile.cs` - Added XML docs (50 lines)
- `Domain/Entities/ProfileClass.cs` - Added XML docs (22 lines)
- `Eneve.Domain.csproj` - Enabled GenerateDocumentationFile property

#### Issues/Blockers
- None

#### Metrics
- 10 entity classes documented (10/15 domain entities complete, 67%)
- 100% public API coverage for these classes
- ~335 lines of XML documentation added
- Estimated 5 entity classes remaining (33%)

#### Next Steps
- Document remaining 5 entity classes (Calendar, CalendarEntry, CalendarDate, MeasurementUnit, + 1 more)
- Validate XML documentation builds without warnings (dotnet build)
- Update README with documentation guidelines for future entity additions
```

### 📝 Context Updated

Updated `tickets/EBASE-13017/context.md`:

**Current Technical State**:
- 10 of 15 domain entity classes documented (67%)
- GenerateDocumentationFile enabled
- Documentation pattern established (business-focused, examples, complete coverage)

**Focus Areas**:
- Complete remaining 5 entity classes
- Validate build with no warnings
- Update README with guidelines

**Immediate Next Steps**:
1. Document Calendar, CalendarEntry, CalendarDate entities
2. Document MeasurementUnit and final entity
3. Run build validation (dotnet build with XML doc warnings enabled)

### 📊 Status Assessment

- Completion: 67% (10/15 entities complete, 67%)
- Remaining work: 5 entities + validation + README
- On track: Yes - ~2 hours remaining at current pace (30 min per entity)

### ⏭️ Next Steps

1. Document remaining 5 entity classes
2. Build validation (ensure zero warnings)
3. Update README with documentation guidelines

**Files Updated**:
- `tickets/EBASE-13017/progress.md` - New entry appended
- `tickets/EBASE-13017/context.md` - Current state updated with 67% completion
```
