# Stack-Agnostic Architecture Patterns

**Purpose:** Portable patterns for Arrow+Ray+Redpanda migration
**Security Model:** Private network with perimeter security at Cloudflare tunnel/edge
**Target:** Docker-Linux bare-metal deployment

---

## PORTABLE PATTERNS (100% Transferable)

### Domain Logic (Pure Python - No Framework Dependencies)

| Pattern | Portability | Notes |
|---------|-------------|-------|
| Sentiment Analysis | 100% | Lexicon-based, 5 modifiers, pure Python |
| Emotion Detection | 100% | 7-category classifier, deterministic rules |
| NPS Calculation | 100% | 4 methods (SHIFTED, STANDARD, ABSOLUTE, WEIGHTED) |
| Churn Risk Scoring | 100% | 6 override rules, component-based calculation |
| Pain Point Classification | 100% | 21-category taxonomy, keyword-based |
| Text Normalization | 100% | NFC Unicode, lowercase, single-space |
| Duplicate Detection | 100% | SHA256 exact, SequenceMatcher near-duplicate |
| Quality Assessment | 100% | Word count, gibberish detection |
| Score Correction | 100% | Discrepancy resolution logic |
| Analysis Score Selection | 100% | Decision tree for score source |

### Data Contracts

| Contract | Schema | Notes |
|----------|--------|-------|
| Input | rating (0-10), comment (string) | Minimum viable schema |
| Output | 36 columns, 6 functional groups | See TECHNICAL_SPEC section 4.2 |
| Cache Key | `SHA256(f"{language}:{normalized_comment}")[:16]` | Any KV store compatible |
| Cache Value | v3.1 schema, NPS excluded | Ground truth recomputation |

### Business Rules

| Rule | Implementation | Notes |
|------|----------------|-------|
| NPS never cached | Recompute from rating | Ground truth preservation |
| PRICING > BILLING | 2x boost when both detected | Pain point priority |
| Churn quality gate | min 3 words, not generic | Data quality enforcement |
| Discrepancy threshold | gap >= 5.0 triggers correction | Cost optimization |
| Auto-approve schema | confidence >= 0.85 | User experience |

### Configurable Thresholds (64 Parameters)

All thresholds in centralized config, no magic numbers:
- Sentiment: Positive >= 7.0, Neutral 4.0-6.9, Negative < 4.0
- Churn: CRITICAL 80+, HIGH 60-79, MEDIUM 40-59, LOW 0-39
- Review Priority: rating 40pts, churn 30pts, exit 20pts, actionability 10pts
- Schema confidence: auto 0.85, production min 0.70, fuzzy scale 50-100

---

## PATTERNS TO ADAPT (Framework Migration)

### Celery -> Ray

| Current (Celery) | Target (Ray) | Migration Path |
|------------------|--------------|----------------|
| Worker pool | Ray actors | Replace @celery_task with @ray.remote |
| Redis broker | Ray internal | Remove broker dependency |
| Task results in Redis | Ray object store | Zero-copy data passing |
| Fixed concurrency (4) | Dynamic scaling | Auto-scale to zero |
| Manual batch sizing | Adaptive placement | Memory-aware scheduling |

**Preserved Patterns:**
- Async task submission
- Progress tracking (11-stage)
- Task cancellation support
- Batch processing logic

### pandas DataFrame -> PyArrow Table

| Current (pandas) | Target (Arrow) | Migration Path |
|------------------|----------------|----------------|
| df.apply() | pc.compute() | PyArrow compute functions |
| df.groupby() | Table.group_by() | Zero-copy grouping |
| Memory copies | Zero-copy sharing | Arrow IPC |
| Python objects | Native types | Type-safe columns |

**Preserved Patterns:**
- Column operations
- Aggregations
- Filtering logic
- All 36 output columns

### Redis Cache -> Redpanda + KV

| Current (Redis) | Target (Redpanda) | Migration Path |
|-----------------|-------------------|----------------|
| Redis hot cache | Redpanda + embedded KV | Topic-based hot data |
| 7-day TTL | Retention policies | Time-based compaction |
| mget/mset batch | Batch produce/consume | Kafka-compatible API |
| Pub/sub | Topic subscription | Event streaming |

**Preserved Patterns:**
- Two-tier architecture (hot/cold)
- Cache key generation (SHA256)
- Schema versioning (v3.1)
- Bypass mode flag

---

## PATTERNS TO REMOVE (Private Network Model)

### Internal Rate Limiting -> Edge Only

| Remove | Reason |
|--------|--------|
| Per-endpoint rate limits | Cloudflare handles at edge |
| 120/min polling limits | Internal services trusted |
| Mutation throttling | No public exposure |

**Edge handles:** DDoS, bot protection, rate limiting, WAF

### Internal Authentication -> Not Required

| Remove | Reason |
|--------|--------|
| API key validation | Private network only |
| JWT middleware | Services trust each other |
| Session management | Edge handles user auth |

**Cloudflare handles:** User authentication, session, access policies

### Platform-Specific Scripts -> Linux Only

| Remove | Reason |
|--------|--------|
| Windows .bat scripts | Docker-Linux only |
| WSL Docker setup | Native Docker daemon |
| macOS Homebrew scripts | Container-based |

**Keep:** docker-compose.yml, Dockerfile, health endpoints

### Memory Constraints -> Ray Managed

| Remove | Reason |
|--------|--------|
| Manual 4GB caps | Ray object store handles |
| LRU eviction logic | Arrow memory pools |
| OOM prevention code | Ray auto-spills to disk |

---

## INTERFACE CONTRACTS (Vendor-Agnostic)

### ICache (Any KV Store)

```
get(key: str) -> Optional[CacheEntry]
set(key: str, value: CacheEntry, ttl: int) -> bool
get_many(keys: List[str]) -> Dict[str, CacheEntry]
set_many(entries: Dict[str, CacheEntry], ttl: int) -> int
delete(key: str) -> bool
exists(key: str) -> bool
```

### IAnalyzer (Any LLM Provider)

```
analyze(comment: str, language: str) -> AnalysisResult
analyze_batch(comments: List[str], language: str) -> List[AnalysisResult]
estimate_cost(comments: List[str]) -> CostEstimate
```

### IExporter (Any Output Format)

```
export(data: Table, format: str, options: Dict) -> ExportResult
get_supported_formats() -> List[str]
validate_options(format: str, options: Dict) -> ValidationResult
```

### IStorage (Any File System)

```
read(path: str) -> bytes
write(path: str, data: bytes) -> bool
exists(path: str) -> bool
list(pattern: str) -> List[str]
```

---

## OBSERVABILITY PATTERNS (Keep All)

| Pattern | Implementation | Target |
|---------|----------------|--------|
| Health endpoints | /health, /ready, /live | K8s probes |
| Correlation IDs | X-Request-ID header | Distributed tracing |
| Structured logging | JSON format, context injection | Log aggregation |
| Cost tracking | Token counts, API costs | Budget enforcement |
| Progress tracking | 11-stage pipeline events | Real-time monitoring |
| Circuit breaker | 5-failure threshold, 30s recovery | Fault tolerance |

---

## ERROR HANDLING (Keep All)

### Exception Hierarchy

```
BaseException
  DomainException (business logic)
    SchemaValidationError -> 422
    ProcessingError -> 500
    AnalysisError -> 500
  ApplicationException (use cases)
    FileValidationError -> 400
    TaskNotFoundError -> 404
  InfrastructureException (external)
    CacheError -> 503
    OpenAIServiceError -> 502
    TimeoutError -> 504
```

### Decorator Pattern

```
@handle_errors(retry=3, timeout=30, fallback=None)
@circuit_breaker(threshold=5, recovery=30)
@with_correlation_id
@log_execution_time
```

---

## BATCH PROCESSING (Keep Logic, Adapt Implementation)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Default batch size | 150 | Adaptive based on memory |
| Parallel workers | 6 | Ray manages dynamically |
| Rate limit | 5 RPS | OpenAI constraint |
| Deduplication | Pre-analysis | 15-20% savings |
| Broadcast | Post-analysis | Results to duplicates |

### Pipeline Stages (6 Phases, 29 Steps)

1. Upload & Validation (5 steps)
2. Pre-Processing (4 steps) - Normalization, deduplication
3. AI Analysis (5 steps) - Batched, parallel, cached
4. Post-Processing (7 steps) - Enrichment, scoring
5. Score Correction (2 steps) - Conditional on discrepancy
6. Export (6 steps) - Format-agnostic output

---

## PERFORMANCE BENCHMARKS (Target Metrics)

| Metric | Current | Target | Notes |
|--------|---------|--------|-------|
| Cost per comment | $0.00045 | $0.00030 | Arrow efficiency |
| Throughput | 40/sec | 100/sec | Ray parallelism |
| Memory efficiency | pandas baseline | 2-3x better | Arrow zero-copy |
| Cold start | 5-10s | <1s | Ray workers warm |
| Cache hit rate | 40-60% | 60-80% | Redpanda persistence |

---

## FRONTEND-AGNOSTIC API CONTRACT

### Endpoints (REST)

```
POST /api/upload          -> {task_id, schema, preview, cost_estimate}
GET  /api/task/{id}       -> {status, progress, rows, time, cache_hit_rate}
POST /api/export          -> {format, url, metadata}
GET  /api/health          -> {status, services}
```

### WebSocket (Optional)

```
WS /ws/task/{id}          -> {stage, progress, eta, message}
```

### Event Schema (Redpanda Topics)

```
topic: feedback.uploaded   -> {task_id, file_hash, row_count}
topic: feedback.analyzed   -> {task_id, batch_id, results}
topic: feedback.exported   -> {task_id, format, url}
topic: feedback.error      -> {task_id, error_type, message}
```

---

## MIGRATION CHECKLIST

### Phase 1: Arrow Data Layer
- [ ] Replace pandas with PyArrow Tables
- [ ] Verify all 36 columns preserved
- [ ] Benchmark memory efficiency
- [ ] Test zero-copy operations

### Phase 2: Ray Compute Layer
- [ ] Convert Celery tasks to Ray actors
- [ ] Implement dynamic scaling
- [ ] Preserve batch processing logic
- [ ] Test progress tracking

### Phase 3: Redpanda Event Layer
- [ ] Replace Redis pub/sub with topics
- [ ] Implement cache on Redpanda + KV
- [ ] Preserve TTL logic
- [ ] Test event-driven pipeline

### Phase 4: Validation
- [ ] A/B test old vs new stack
- [ ] Verify all output columns match
- [ ] Benchmark 2x throughput target
- [ ] Verify 40-50% cost reduction

---

## SUMMARY

**100% Portable:** All domain logic, business rules, thresholds, data contracts

**Adapt:** Celery->Ray, pandas->Arrow, Redis->Redpanda

**Remove:** Internal auth, rate limiting, platform scripts, manual memory management

**Keep:** Interfaces, error handling, observability, batch logic, health endpoints

---

**Generated:** 2025-12-13
**Source:** EXTRACTION_SUMMARY.md, TECHNICAL_SPEC_STACK_AGNOSTIC.md
**Target:** Arrow+Ray+Redpanda+Docker-Linux+Cloudflared
