---
type: exemplar
artifact-type: prompt
demonstrates: ticket-execute-plan
domain: ticket workflow
quality-score: exceptional
version: 1.0.0
illustrates: ticket.execute-plan
extracted-from: .cursor/prompts/ticket/execute-plan.prompt.md
---

# Execute Plan Exemplar

## Examples (Few-Shot)

### Example 1: Execute Analysis & Design Plan

**Input**:
```
Execute @execute-plan on @tickets/EPP-192/RISKREDUCTION5/01-dispatchasync-analysis-design/
```

**Reasoning**:
- Plan calls for analyzing DispatchAsync complexity
- Need to identify 5 phases and their complexity sources
- Must design IPersistenceStrategy interface
- Deliverables: design-decisions.md, complexity-analysis.md

**Expected Output**:
```markdown
## 🚀 Executing Plan: EPP-192-RISKREDUCTION5-01

**Folder**: tickets/EPP-192/RISKREDUCTION5/01-dispatchasync-analysis-design/
**Plan**: Analyze DispatchAsync complexity and design IPersistenceStrategy interface
**Phase**: Analysis Complete, Design In Progress

---

### ✅ Steps Completed

#### Step 1: Read and Analyze Source
- ✅ Read DomainObjectPersistenceDispatcher.cs (Lines 92-285)
- ✅ Identified 5 complexity phases
- ✅ Mapped each phase to line numbers and complexity count

#### Step 2: Map Complexity to Phases
- ✅ Phase 1 (Validation): Lines 101-110, complexity 3-5
- ✅ Phase 2 (Type Routing): Lines 112-142, complexity 10-15
- ✅ Phase 3 (Invocation): Lines 144-251, complexity 25-30 ⭐ HOTSPOT
- ✅ Phase 4 (Unsupported): Lines 253-268, complexity 5-8
- ✅ Phase 5 (Aggregation): Lines 270-285, complexity 3-5
- ✅ Total verified: 56 complexity points

#### Step 3: Design Interface
- ✅ Designed IPersistenceStrategy<T> with ExecuteAsync method
- ✅ Added full XML documentation
- ✅ Defined strategy selection mechanism (dictionary by mode)

---

### 📁 Deliverables Created

- ✅ `design-decisions.md` - Interface design rationale and strategy pattern justification
- ✅ `complexity-analysis.md` - Detailed phase-by-phase breakdown with line numbers
- ✅ Updated `plan.md` - Added interface specification section

---

### 🎯 Validation Status

- ✅ All 5 phases identified and documented
- ✅ Complexity sources mapped to specific lines
- ✅ Interface design complete with XML documentation
- ✅ Strategy selection mechanism designed
- ✅ Reflection logic decision documented with rationale
- ✅ Complexity reduction estimate calculated (-38 to -50 points)

---

### ⚠️ Issues / Deviations

None. Plan executed as specified.

---

### ⏭️ Next Steps

**Ready for Sub-Ticket 02**: Interface Creation
- Input: Interface design from this sub-ticket
- Output: IPersistenceStrategy<T> interface file with tests

**Command to continue**:
```
/execute-plan @tickets/EPP-192/RISKREDUCTION5/02-dispatchasync-interface/
```

---

**Progress Updated**: `progress.md` updated with analysis and design session
```

### Example 2: Simple Implementation Execution

**Input**:
```
/execute-plan @tickets/EPP-192/03-add-validation/
```

**Reasoning**:
- Straightforward implementation plan with 3 steps
- Add validation to existing method
- Create unit tests
- Update documentation

**Expected Output**:
```markdown
## 🚀 Executing Plan: EPP-192-03

**Folder**: tickets/EPP-192/03-add-validation/
**Plan**: Add input validation to ProcessPayment method
**Phase**: Complete

---

### ✅ Steps Completed

#### Step 1: Add Validation Logic
- ✅ Added null checks for payment parameter
- ✅ Added range validation for amount (must be > 0)
- ✅ Added ArgumentNullException with descriptive message
- ✅ Added ArgumentOutOfRangeException for invalid amounts

#### Step 2: Create Unit Tests
- ✅ Created PaymentServiceTests.cs
- ✅ Test: ProcessPayment_NullPayment_ThrowsArgumentNullException
- ✅ Test: ProcessPayment_NegativeAmount_ThrowsArgumentOutOfRangeException
- ✅ Test: ProcessPayment_ZeroAmount_ThrowsArgumentOutOfRangeException
- ✅ Test: ProcessPayment_ValidPayment_Succeeds
- ✅ All tests passing ✅

#### Step 3: Update Documentation
- ✅ Added XML documentation for exceptions
- ✅ Updated method summary with validation behavior
- ✅ Added <exception> tags for both exception types

---

### 📁 Deliverables Created

- ✅ `PaymentService.cs` - Modified with validation logic
- ✅ `PaymentServiceTests.cs` - New test file with 4 tests
- ✅ Updated XML documentation in PaymentService.cs

---

### 🎯 Validation Status

- ✅ Validation logic prevents null input
- ✅ Validation logic prevents invalid amounts
- ✅ All unit tests passing (4/4)
- ✅ Test coverage for validation: 100%
- ✅ XML documentation complete

---

### ⚠️ Issues / Deviations

None. Simple plan executed as specified.

---

### ⏭️ Next Steps

**Mark ticket complete** using `/complete-ticket`

---

**Progress Updated**: `progress.md` updated with validation implementation session
```

### Example 3: Blocked Execution with Documentation

**Input**:
```
/execute-plan @tickets/EPP-192/04-database-migration/
```

**Reasoning**:
- Plan requires database schema changes
- Discovered missing prerequisite: staging database not available
- Cannot proceed with execution, must document blocker

**Expected Output**:
```markdown
## 🚀 Executing Plan: EPP-192-04 [BLOCKED]

**Folder**: tickets/EPP-192/04-database-migration/
**Plan**: Create migration script for new UserPreferences table
**Phase**: Blocked at Step 1 (Environment Setup)

---

### ✅ Steps Completed

#### Step 1: Verify Prerequisites
- ✅ Read plan.md thoroughly
- ✅ Identified requirement: staging database connection
- ❌ **BLOCKER**: Staging database not configured in connection string

---

### 📁 Deliverables Created

- ⚠️ None yet - blocked before implementation

---

### 🎯 Validation Status

- ❌ Cannot validate - execution blocked

---

### ⚠️ Issues / Deviations

**BLOCKER**: Staging database not available

**Details**:
- Plan requires staging database connection for testing migration
- Connection string missing in appsettings.json
- Need infrastructure team to provide connection details

**Resolution Required**:
1. Contact infrastructure team for staging DB credentials
2. Update appsettings.json with connection string
3. Verify connection works
4. Resume execution

---

### ⏭️ Next Steps

**Action Required**: Resolve blocker before continuing
- [ ] Request staging DB access from infrastructure team
- [ ] Update connection string
- [ ] Test connection
- [ ] Resume execution with `/execute-plan` again

---

**Progress Updated**: `progress.md` updated with blocker documentation
```

