# Target Architecture Reference

**Purpose:** Consolidated target architecture for the feedback-arrow system
**Status:** Canonical reference (source files archived)
**Updated:** 2025-12-19

---

## 1. DATA FLOW ARCHITECTURE

### 1.1 Pipeline Flow

```
[Upload] -> [Arrow Table] -> [IComputeGraph]
                                   |
                 +-----------------+-----------------+
                 |                 |                 |
                 v                 v                 v
          [Sampling]       [Deduplication]    [Schema]
          (IComputeNode)   (IComputeNode)    (IComputeNode)
                 |                 |                 |
                 +-----------------+-----------------+
                                   |
                                   v
                           [Arrow Table]
                           (zero-copy)
                                   |
                     +-------------+-------------+
                     |             |             |
                     v             v             v
              [AI Batch 1]  [AI Batch 2]  [AI Batch N]
              (ILLMProvider) (ILLMProvider) (ILLMProvider)
                     |             |             |
                     +-------------+-------------+
                                   |
                                   v
                           [Merge Results]
                           (Arrow concat)
                                   |
                                   v
                           [IExporter]
                                   |
                                   v
                           [Parquet/CSV/Sheets]
```

### 1.2 Transformation Stages

| Stage | Input | Output | Arrow Operation |
|-------|-------|--------|-----------------|
| Upload | CSV/Excel/Parquet | Arrow Table | `pa.csv.read_csv()` |
| Normalize | Arrow Table | Arrow Table + normalized_comment | `pc.utf8_lower()` |
| Deduplicate | Arrow Table | Arrow Table + hash/group columns | `pa.compute` |
| Analyze | Arrow Table | Arrow Table + analysis columns | ILLMProvider batches |
| Aggregate | Arrow Table | Summary metrics | `pc.sum()`, `pc.mean()` |
| Export | Arrow Table | File/API | IExporter formats |

---

## 2. PRODUCTION STACK

### 2.1 Core Components

```
Arrow (FORMAT - Unconditional)
  - Memory layout contract
  - Zero-copy data sharing
  - All data flows as pa.Table

DataFusion (PIPELINE ENGINE)
  - Apache-governed Rust query engine
  - Algebraic optimization
  - Substrait export for portability

Parquet (COLD STORAGE)
  - Arrow's native file format
  - Columnar, compressed
  - Zero deserialization overhead

DuckDB (QUERY INTERFACE)
  - MIT license, DuckDB Foundation
  - Zero-copy Arrow interchange
  - SQL interface for debugging
```

### 2.2 Parallelism Strategy

```
Sync Python + Rust Parallelism (DEFAULT)
  - Python stays synchronous for orchestration
  - Polars/Rayon handles CPU parallelism internally
  - httpx + anyio for isolated I/O async (LLM calls only)

AVOID:
  - ProcessPoolExecutor (pickling, fork/spawn issues)
  - asyncio contamination (event loop complexity)
```

### 2.3 Orchestration Hierarchy

| Tier | Tool | Use Case | Risk |
|------|------|----------|------|
| 1 | Polars + httpx/anyio | Default, single-machine | Low |
| 2 | DataFusion | Pipeline with optimization | None (Apache) |
| 3 | DuckDB | Query/debug/observability | None (MIT) |
| 4 | Dask | Scale-out if needed | Low |
| 5 | Ray | ONLY if customer demands | HIGH (Anyscale) |

---

## 3. KEY IMPLEMENTATION PATTERNS

### 3.1 Arrow-Native Data Operations

```python
# File reading
table = pa.csv.read_csv(file_path)

# Filtering
filtered_table = table.filter(pc.field('column') > threshold)

# Column operations
table = table.append_column('normalized', pc.utf8_lower(table['comment']))

# Zero-copy slice
batch = table.slice(offset, length)
```

### 3.2 ILLMProvider Integration

```python
class ILLMProvider(Protocol):
    """LLM abstraction - swappable implementations."""

    async def analyze_batch(
        self,
        comments: pa.Array,
        config: AnalysisConfig
    ) -> pa.RecordBatch:
        """Analyze batch, return Arrow-native results."""
        ...
```

### 3.3 Provider Hierarchy (Local-First)

```
Priority 1-9: LOCAL PROVIDERS (Zero Cost)
├── Ollama        → http://localhost:11434 (default)
├── vLLM          → http://localhost:8000
├── llama.cpp     → http://localhost:8080
└── LM Studio     → http://localhost:1234

Priority 10+: CLOUD PROVIDERS (Pay-per-use)
├── OpenAI        → https://api.openai.com
├── Anthropic     → https://api.anthropic.com
└── Groq/Together → Various endpoints
```

### 3.4 Cache Architecture

```python
class ICache(Protocol):
    """Two-tier caching - provider agnostic."""

    def get(self, key: str) -> Optional[bytes]:
        # Try hot tier (memory/Redis)
        # Fall back to cold tier (Parquet/filesystem)
        ...

    def set(self, key: str, value: bytes, ttl: int) -> None:
        # Write to both tiers
        ...
```

**Cache Key Generation (Provider-Agnostic):**
```python
def generate_cache_key(comment: str, language: str) -> str:
    normalized = normalize_text(comment)
    content = f"{language}:{normalized}"
    return hashlib.sha256(content.encode()).hexdigest()[:16]
```

---

## 4. PERFORMANCE CHARACTERISTICS

### 4.1 Expected Metrics

| Metric | Target |
|--------|--------|
| Memory (10K comments) | ~500MB |
| Serialization overhead | ~0 (zero-copy) |
| Cache hit latency | 1-5ms |
| Large file support | 100K+ rows (stream-processable) |
| Cold start | 1-2s |

### 4.2 Batch Processing Configuration

```python
BATCH_SIZE = {
    "ollama_7b": 10,       # Memory-bound
    "ollama_13b": 5,
    "vllm": 50,            # Continuous batching
    "openai": 50,          # Rate-limit-bound
    "anthropic": 30,
}

CONCURRENT_WORKERS = {
    "local": 1,            # Single GPU typically
    "cloud": 6,            # API can handle parallel
}
```

### 4.3 Cost Model

```
LOCAL PROVIDERS:
├── Ollama:    $0.00 (electricity only)
├── vLLM:      $0.00 (electricity only)
└── llama.cpp: $0.00 (electricity only)

CLOUD PROVIDERS:
├── OpenAI gpt-4o-mini:     $0.15/$0.60 per 1M tokens
├── Anthropic Haiku:        $0.25/$1.25 per 1M tokens
└── Groq Llama3-70b:        $0.59/$0.79 per 1M tokens
```

**With local-first: 95% of requests at $0.00, ~5% cloud fallback.**

---

## 5. VALIDATION REQUIREMENTS

### 5.1 Golden Dataset Structure

```
golden-datasets/
├── telecom_1000/
│   ├── input.csv           # Original feedback
│   ├── expected_output.json # Expected results
│   └── validation_rules.json # Tolerances
└── retail_500/
    └── ...
```

### 5.2 Column-Level Validation

| Column | Type | Tolerance |
|--------|------|-----------|
| User Score | int | Exact |
| Sentiment Score | float | ±0.1 |
| Emotion (7 values) | float | ±0.15 |
| Churn Risk Score | float | ±0.1 |
| Pain Point Category | str | Synonyms allowed |
| Is Duplicate | bool | Exact |

### 5.3 Aggregate-Level Validation

| Metric | Tolerance |
|--------|-----------|
| NPS Score | ±2 points |
| NPS Distribution | ±2% per category |
| Avg Churn Risk | ±0.05 |
| Pain Point Distribution | ±3% per category |

### 5.4 Validation Checklist

- [ ] Pain point classification produces same categories
- [ ] Churn risk scores within tolerance
- [ ] Behavioral flags match (exit threats, competitors, etc.)
- [ ] Duplicate detection identifies same duplicates
- [ ] NPS calculations match
- [ ] Emotion aggregations within tolerance
- [ ] Export has correct structure
- [ ] Large files (100K+ rows) process successfully

---

## 6. ARROW INTEGRATION NOTES

### 6.1 Node Input/Output Validation

```python
def validated_node(func):
    """Decorator to validate Arrow tables at node boundaries."""
    def wrapper(input_table: pa.Table, expected_input: pa.Schema,
                expected_output: pa.Schema) -> pa.Table:
        # Validate input
        assert input_table.schema.equals(expected_input)
        input_rows = input_table.num_rows

        # Execute
        output_table = func(input_table)

        # Validate output
        assert output_table.schema.equals(expected_output)
        output_table.validate()

        return output_table
    return wrapper
```

### 6.2 Polars-Arrow Round-Trip

```python
def safe_polars_transform(arrow_table: pa.Table, transform_fn) -> pa.Table:
    """Safely transform via Polars with validation."""
    input_cols = arrow_table.num_columns

    polars_df = pl.from_arrow(arrow_table)
    result_df = transform_fn(polars_df)
    output_table = result_df.to_arrow()

    # Validate no column loss
    assert output_table.num_columns >= input_cols
    return output_table
```

### 6.3 Validation Points

| Stage | Validation |
|-------|------------|
| Excel Ingestion | Schema detection + column mapping |
| Arrow Conversion | `pa.Table.validate()` |
| Each Node Entry | `schema.equals(expected)` |
| Each Node Exit | Row count invariant + schema check |
| Parquet Write | Checksum in metadata |

---

## 7. CROSS-REFERENCE

| Topic | Authoritative Document |
|-------|------------------------|
| IComputeNode/IComputeGraph | `COMPUTE_GRAPH_SPEC.md` |
| Node implementations | `COMPUTE_NODES_SPEC.md` |
| IStateStore/IPersistence | `STATE_STORE_SPEC.md` |
| Pipeline DAG definition | `PIPELINE_DEFINITION.md` |
| ILLMProvider interface | `LLM_PROVIDER_CONTRACT.md` |
| IExporter interface | `EXPORT_CONTRACT.md` |
| Language packs | `LANGUAGE_PACK_SPEC.md` |
| API contract | `API_CONTRACT.md` |

---

**Source Files:** Extracted from `ARCHITECTURE_DEEP_DIVE.md`, `TECHNICAL_SPEC_STACK_AGNOSTIC.md`, `EXTRACTED_DOMAIN_LOGIC.md` (now in `_archive/`)
