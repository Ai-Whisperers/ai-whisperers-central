---
type: exemplar
artifact-type: prompt
demonstrates: ticket-start
domain: ticket workflow
quality-score: exceptional
version: 1.0.0
illustrates: ticket.start-ticket
extracted-from: .cursor/prompts/ticket/start-ticket.prompt.md
---

# Ticket Start Exemplar

## Examples (Few-Shot)

### Example 1: Simple Fix Ticket

**Input**:
```xml
<ticket>
  <id>EPP-198</id>
  <action>start ticket</action>
  <context>Fix memory leak in CacheManager</context>
</ticket>
```

**Reasoning**:
- Single component (CacheManager)
- Clear problem (memory leak)
- Focused change (disposal logic)
- Estimated 1-2 days
→ Classification: Simple Fix

**Expected Output**:
```markdown
## ✅ Ticket Initialized: EPP-198

**Ticket**: EPP-198
**Summary**: Fix memory leak in CacheManager
**Complexity**: Simple Fix

---

### 📁 Folder Structure Created

```
tickets/EPP-198/
  ├── plan.md          ✅ Created
  ├── context.md       ✅ Created
  ├── progress.md      ✅ Created
  └── references.md    ⚠️ Optional (create as needed)
```

---

### 📊 Complexity Assessment

**Classification**: Simple Fix

**Rationale**:
- Single component affected (CacheManager.cs)
- Clear problem scope (memory leak from WeakReference not cleared)
- Focused solution (add explicit Dispose cleanup)
- Low risk (isolated change, comprehensive tests exist)
- Estimated effort: 1-2 days (investigation + fix + testing)

**Estimated Effort**: 1-2 days
**Risk Level**: Low
**Components Affected**: 1 component (CacheManager)

---

### 📋 Implementation Plan

**Strategy**: Identify root cause via memory profiler, implement explicit cleanup in Dispose method, add validation to prevent recurrence.

**Work Breakdown**:

**Phase 1**: Investigation (Day 1)
- Profile memory usage with diagnostics tools
- Identify WeakReference retention points
- Document root cause in RCA

**Phase 2**: Fix Implementation (Day 1-2)
- Add explicit WeakReference.SetTarget(null) in Dispose
- Verify cleanup with memory profiler
- Add unit test for disposal behavior

**Phase 3**: Prevention (Day 2)
- Add CI validation for proper Dispose implementations
- Update code review checklist
- Document WeakReference best practices

**Total Tasks**: 7 tasks across 3 phases

---

### 🔗 Dependencies Identified

**Internal**:
- CacheManager (existing component to modify)

**External**:
- Memory profiler tools (for diagnosis)
- Existing test suite (for regression validation)

---

### ⚠️ Risks & Questions

**Risks**:
- Risk: Fix may not fully resolve leak → Mitigation: Use memory profiler to verify
- Risk: Disposal timing may affect existing code → Mitigation: Comprehensive regression testing

**Questions Needing Resolution**:
- [ ] Are there other WeakReference usages in codebase with similar issue?
- [ ] What memory profiler tools are available for diagnosis?

---

### 🌿 Git Branch Suggestion

```bash
# Create branch
git checkout -b fix/EPP-198-cache-manager-memory-leak develop

# Branch naming
fix/EPP-198-cache-manager-memory-leak
```

---

### ⏭️ Ready to Start

**Next Steps**:
1. Profile current memory usage to identify leak pattern
2. Document root cause findings in tickets/EPP-198/rca.md
3. Implement Dispose cleanup fix

**Start with**:
```xml
<ticket><id>@EPP-198</id><action>please start with Phase 1: Investigation</action></ticket>
```

---

**Files Created**:
- `tickets/EPP-198/plan.md`
- `tickets/EPP-198/context.md`
- `tickets/EPP-198/progress.md`
- `tickets/current.md` (updated)
```

### Example 2: Complex Implementation Ticket

**Input**:
```xml
<ticket>
  <id>EBASE-12345</id>
  <action>start ticket</action>
  <context>Implement repository pattern for 14 configuration entities across 5 domains</context>
</ticket>
```

**Reasoning**:
- Multiple entities (14 repositories)
- Multiple domains (5: Markets, Products, Profiles, Calendars, Units)
- Pattern implementation (repository + UnitOfWork)
- Multi-phase work (infrastructure, then domains)
- Estimated 5-7 days
→ Classification: Complex Implementation

**Expected Output**:
```markdown
## ✅ Ticket Initialized: EBASE-12345

**Ticket**: EBASE-12345
**Summary**: Implement repository pattern for 14 configuration entities across 5 domains
**Complexity**: Complex Implementation

---

### 📁 Folder Structure Created

```
tickets/EBASE-12345/
  ├── plan.md          ✅ Created
  ├── context.md       ✅ Created
  ├── progress.md      ✅ Created
  ├── tracker.md       ✅ Created (for systematic work tracking)
  └── references.md    ⚠️ Optional (create as needed)
```

---

### 📊 Complexity Assessment

**Classification**: Complex Implementation

**Rationale**:
- Multiple entities: 14 repositories across 5 domains (Markets, Products, Profiles, Calendars, Units)
- Architectural pattern: Implementing repository pattern + UnitOfWork integration
- Multi-phase work: Infrastructure setup, then domain-by-domain implementation
- Medium risk: Affects data access layer, requires careful transaction management
- Estimated effort: 5-7 days (infrastructure + 14 repositories + testing)

**Estimated Effort**: 5-7 days
**Risk Level**: Medium
**Components Affected**: 14 entities, 5 domains, UnitOfWork pattern, data access layer

---

### 📋 Implementation Plan

**Strategy**: Implement generic repository base classes and UnitOfWork pattern first, then systematically create concrete repositories for each domain. Use Dapper for data access with async throughout.

**Work Breakdown**:

**Phase 1**: Core Infrastructure (Day 1-2)
- [ ] Create IRepository<T> interface
- [ ] Implement RepositoryBase<T> with Dapper
- [ ] Create IUnitOfWork interface
- [ ] Implement UnitOfWork with transaction management
- [ ] Create entity mappers (domain ↔ database)
- [ ] Unit tests for base infrastructure

**Phase 2**: Markets Domain (Day 3)
- [ ] Country repository
- [ ] Market repository
- [ ] GridPointType repository
- [ ] MarketParty repository
- [ ] MarketRole repository
- [ ] UnitOfWork implementation for Markets

**Phase 3**: Products Domain (Day 4)
- [ ] MeterProduct repository
- [ ] MeterPictogram repository
- [ ] PhysicalProduct repository
- [ ] UnitOfWork implementation for Products

**Phase 4**: Profiles Domain (Day 4-5)
- [ ] Profile repository
- [ ] ProfileClass repository
- [ ] UnitOfWork implementation for Profiles

**Phase 5**: Calendars Domain (Day 5-6)
- [ ] Calendar repository
- [ ] CalendarEntry repository
- [ ] CalendarDate repository
- [ ] UnitOfWork implementation for Calendars

**Phase 6**: Units Domain (Day 6)
- [ ] MeasurementUnit repository
- [ ] UnitOfWork implementation for Units

**Phase 7**: Testing & Integration (Day 6-7)
- [ ] Integration tests for each repository
- [ ] Transaction rollback testing
- [ ] Performance validation
- [ ] Documentation updates

**Total Tasks**: 35+ tasks across 7 phases

---

### 🔗 Dependencies Identified

**Internal**:
- Domain entities (existing models for 14 configuration tables)
- Database schema (configuration tables in MSSQL)
- Connection management (existing ADO.NET infrastructure)

**External**:
- Dapper (ORM for data access) - current version
- System.Data.SqlClient (MSSQL provider)

---

### ⚠️ Risks & Mitigations

**Risks**:
- **Risk**: Transaction management complexity → **Mitigation**: Comprehensive UnitOfWork tests with rollback scenarios
- **Risk**: Performance impact from N+1 queries → **Mitigation**: Use Dapper multi-mapping, validate with profiler
- **Risk**: Breaking existing data access code → **Mitigation**: Incremental rollout, maintain backward compatibility initially

**Questions Needing Resolution**:
- [ ] Should we support both sync and async operations or async-only?
- [ ] What's the transaction isolation level requirement?
- [ ] Are there existing conventions for entity mapping?

---

### 🌿 Git Branch Suggestion

```bash
# Create branch
git checkout -b feature/EBASE-12345-repository-pattern-config-entities develop

# Branch naming
feature/EBASE-12345-repository-pattern-config-entities
```

---

### ⏭️ Ready to Start

**Next Steps**:
1. Create core repository interfaces (IRepository<T>, IUnitOfWork)
2. Implement RepositoryBase<T> with Dapper
3. Create first concrete repository (Country) as pattern

**Start with**:
```xml
<ticket><id>@EBASE-12345</id><action>please start with Phase 1: Core Infrastructure</action></ticket>
```

**Tracking Strategy**: Use tracker.md for systematic progress across 14 repositories

---

**Files Created**:
- `tickets/EBASE-12345/plan.md`
- `tickets/EBASE-12345/context.md`
- `tickets/EBASE-12345/progress.md`
- `tickets/EBASE-12345/tracker.md` (for systematic work)
- `tickets/current.md` (updated)
```

