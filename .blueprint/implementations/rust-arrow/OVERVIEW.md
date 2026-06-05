# Plan: Rust-Native Implementation of Feedback-Arrow

## Summary

Rewrite feedback-arrow in pure Rust using Arrow-rs, DataFusion, DuckDB-rs, Axum, and reqwest. The existing Python blueprint specifications remain valid for interfaces and algorithms - only the implementation language changes.

## Rationale

- **Debugging**: Rust's compiler catches errors at build time, eliminating Python runtime type errors
- **Performance**: No GIL, native Arrow/DataFusion without Python bindings overhead
- **Deployment**: Single static binary, no Python runtime dependencies
- **LLM Simplicity**: LLM calls are just HTTP + JSON - reqwest + serde handles this cleanly

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    feedback-arrow CLI/API               │
│                      (Axum + Clap)                      │
├─────────────────────────────────────────────────────────┤
│  fa-graph    │  fa-nodes   │  fa-llm    │  fa-state    │
│  (DAG exec)  │  (16 nodes) │  (adapters)│  (storage)   │
├─────────────────────────────────────────────────────────┤
│              fa-core (traits + types)                   │
├─────────────────────────────────────────────────────────┤
│        arrow-rs  │  datafusion  │  duckdb-rs           │
└─────────────────────────────────────────────────────────┘
```

## Repository Structure

Cargo workspace at repo root, blueprint becomes reference documentation:

```
feedback-arrow/
├── Cargo.toml                    # Workspace root
├── Cargo.lock
├── blueprint/                    # Existing specs (reference docs)
├── language_packs/               # JSON resources (unchanged)
├── crates/
│   ├── fa-core/                  # Traits: LLMProvider, ComputeNode, ComputeGraph
│   ├── fa-arrow/                 # Arrow utilities, schema helpers
│   ├── fa-llm/                   # Ollama, OpenAI, Anthropic adapters
│   ├── fa-nodes/                 # 16 compute node implementations
│   ├── fa-graph/                 # DAG builder, executor, optimizer
│   ├── fa-state/                 # Memory, Redis, DuckDB stores
│   ├── fa-config/                # TOML/env configuration
│   ├── fa-api/                   # Axum REST API
│   └── fa-cli/                   # CLI binary
└── language_packs/               # JSON resources (unchanged)
```

## Core Dependencies

| Purpose | Crate | Version |
|---------|-------|---------|
| Arrow | `arrow`, `parquet` | 53 |
| Query Engine | `datafusion` | 43 |
| SQL/Debug | `duckdb` | 1 |
| Async Runtime | `tokio` | 1.41 |
| HTTP Client | `reqwest` | 0.12 |
| HTTP Server | `axum` | 0.7 |
| Serialization | `serde`, `serde_json` | 1 |
| Error Handling | `thiserror`, `anyhow` | latest |

## Key Trait Translations

### ILLMProvider (3 methods)
```rust
#[async_trait]
pub trait LLMProvider: Send + Sync {
    fn capabilities(&self) -> &ProviderCapabilities;
    async fn analyze_batch(&self, request: AnalysisRequest) -> Result<Vec<AnalysisResult>, LLMError>;
    async fn health_check(&self) -> bool;
}
```

### IComputeNode (8 methods)
```rust
#[async_trait]
pub trait ComputeNode: Send + Sync {
    fn node_id(&self) -> &str;
    fn node_type(&self) -> &str;
    fn input_schema(&self) -> Option<Arc<Schema>>;
    fn output_schema(&self) -> Arc<Schema>;
    fn dependencies(&self) -> &[String];
    async fn transform(&self, data: Option<RecordBatch>, ctx: &ExecutionContext) -> Result<NodeResult, NodeError>;
    fn resource_requirements(&self) -> ResourceSpec;
    fn validate_input(&self, data: &RecordBatch) -> Vec<String>;
}
```

## LLM Adapter Pattern

All adapters use `reqwest` + `serde`:

```rust
// OpenAI-compatible base (Ollama, vLLM, OpenAI share this)
impl LLMProvider for OpenAICompatibleAdapter {
    async fn analyze_batch(&self, request: AnalysisRequest) -> Result<Vec<AnalysisResult>, LLMError> {
        let response = self.client
            .post(&format!("{}/v1/chat/completions", self.base_url))
            .json(&ChatCompletionRequest { ... })
            .send().await?;
        // Parse JSON response with serde
    }
}

// Anthropic needs custom format (~100 lines)
impl LLMProvider for AnthropicAdapter { ... }
```

## Implementation Phases

### Phase 1: Foundation (First)
- [ ] `fa-core/traits/` - All trait definitions
- [ ] `fa-core/types/` - Domain types, errors
- [ ] `fa-arrow/` - Schema helpers, table operations
- [ ] `fa-config/` - TOML + env loading

### Phase 2: Core Services
- [ ] `fa-state/memory.rs` - In-memory StateStore
- [ ] `fa-state/persistence/duckdb.rs` - DuckDB persistence
- [ ] `fa-llm/adapters/ollama.rs` - First LLM adapter

### Phase 3: Node Implementation
- [ ] `fa-nodes/source/file_reader.rs` - CSV/Parquet input
- [ ] `fa-nodes/transform/normalize.rs` - Text normalization
- [ ] `fa-nodes/transform/deduplicate.rs` - Deduplication
- [ ] `fa-nodes/llm/sentiment.rs` - LLM sentiment node
- [ ] `fa-nodes/sink/parquet.rs` - Parquet output

### Phase 4: Graph Execution
- [ ] `fa-graph/graph.rs` - DAG implementation
- [ ] `fa-graph/executor.rs` - Topological execution

### Phase 5: API Layer
- [ ] `fa-api/routes/` - REST endpoints
- [ ] `fa-cli/` - CLI commands

### Phase 6: Production
- [ ] Additional LLM adapters (OpenAI, Anthropic)
- [ ] Redis state store
- [ ] Checkpointing
- [ ] Observability (tracing, metrics)

## Blueprint Document Status

| Document | Status | Action |
|----------|--------|--------|
| `COMPUTE_GRAPH_SPEC.md` | Valid | Use as-is |
| `COMPUTE_NODES_SPEC.md` | Valid | Use as-is |
| `LLM_PROVIDER_CONTRACT.md` | Valid | Use as-is |
| `API_CONTRACT.md` | Valid | Use as-is |
| `STATE_STORE_SPEC.md` | Valid | Use as-is |
| `PROJECT_STRUCTURE.md` | Needs Update | Rewrite for Cargo workspace |
| `DI_SPEC.md` | Needs Update | Simplify for Rust ownership |
| `TESTING_SPEC.md` | Needs Update | Rust test patterns |

## First Milestone: POC

Prove the pattern with minimal code:
1. Read CSV → Arrow RecordBatch
2. Call Ollama for sentiment analysis
3. Append results to batch
4. Write Parquet

```rust
// ~50 lines to prove Arrow + LLM integration works
let batch = read_csv("input.csv")?;
let results = ollama.analyze_batch(batch.column("comment")).await?;
let enriched = append_column(batch, "sentiment", results)?;
write_parquet(enriched, "output.parquet")?;
```

## Files to Create First

1. `Cargo.toml` - Workspace definition
2. `crates/fa-core/src/traits/llm_provider.rs` - LLMProvider trait
3. `crates/fa-core/src/traits/compute_node.rs` - ComputeNode trait
4. `crates/fa-llm/src/adapters/ollama.rs` - Ollama adapter
5. `crates/fa-arrow/src/lib.rs` - Schema/table utilities

## Build Output

Single binary deployment:
```bash
cargo build --release
# Produces: target/release/feedback-arrow (~15-30MB static binary)
```

## Success Criteria

- [ ] `cargo build` compiles without warnings
- [ ] `cargo test` passes all unit tests
- [ ] POC processes 1000 rows through Ollama successfully
- [ ] Parquet output matches expected 36-column schema

---

## DETAILED SECTIONS (Expanded Planning)

### 1. Blueprint Updates Strategy

**Current State:** 25 markdown files totaling 25,571 lines

**Documents by Category:**

| Category | Files | Rust Action |
|----------|-------|-------------|
| **Language-Agnostic (Keep As-Is)** | | |
| Interface specs | COMPUTE_GRAPH_SPEC, COMPUTE_NODES_SPEC, LLM_PROVIDER_CONTRACT, STATE_STORE_SPEC | Valid - describes traits |
| API specs | API_CONTRACT, EXPORT_CONTRACT | Valid - OpenAPI/formats |
| Domain specs | LANGUAGE_PACK_SPEC, VALIDATION_SUITE | Valid - JSON resources |
| Architecture | TARGET_ARCHITECTURE, DEPENDENCY_GRAPH, BLINDSPOTS | Valid - conceptual |
| Security/Ops | SECURITY_SPEC, MULTI_TENANCY_SPEC, OPERATIONS_SPEC | Valid - infrastructure |
| Config | CONFIG_SPEC | Valid - TOML works in Rust |
| **Needs Rust Rewrite** | | |
| Project structure | PROJECT_STRUCTURE.md | Rewrite for Cargo workspace |
| DI patterns | DI_SPEC.md | Simplify - Rust ownership model |
| Testing | TESTING_SPEC.md | Rewrite for Rust test patterns |
| **Archive/Consolidate** | | |
| Redundant | AGNOSTIC_BLUEPRINT (2503 lines) | Merge into TRUE_AGNOSTIC_BACKEND |
| Redundant | BLUEPRINT.md | Keep as high-level summary only |
| Meta | IMPLEMENTATION_GAPS.md | Delete after Rust scaffolding |
| Strategy | STRATEGY.md | Archive - decisions made |

**Sync Strategy:**
- Blueprint = specification (what interfaces do)
- Rust code = implementation (how they do it)
- Use `#[doc = include_str!("../../blueprint/LLM_PROVIDER_CONTRACT.md")]` in Rust to embed spec as module docs

---

### 2. Crate Boundaries Analysis

**Current Plan (9 crates):**
```
fa-core, fa-arrow, fa-llm, fa-nodes, fa-graph, fa-state, fa-config, fa-api, fa-cli
```

**Dependency Analysis:**

```
                    fa-cli ←── fa-api
                       ↑         ↑
                       └────┬────┘
                            ↓
                        fa-graph
                            ↑
              ┌─────────────┼─────────────┐
              ↓             ↓             ↓
          fa-nodes      fa-llm       fa-state
              ↑             ↑             ↑
              └─────────────┼─────────────┘
                            ↓
                        fa-arrow
                            ↑
                            ↓
                        fa-core ← fa-config
```

**Alternative: Consolidated (5 crates)**
```
feedback-arrow/
├── crates/
│   ├── fa-core/          # Traits + types + config + arrow utils (merged)
│   ├── fa-pipeline/      # Nodes + graph + LLM adapters (merged)
│   ├── fa-storage/       # State + persistence (merged)
│   ├── fa-server/        # API (Axum)
│   └── fa-cli/           # CLI binary
```

**Recommendation: Start with 5, split if needed**

| Consolidated | Contains | Rationale |
|--------------|----------|-----------|
| `fa-core` | traits, types, config, arrow utils | Always needed together |
| `fa-pipeline` | nodes, graph, llm | Pipeline execution is one unit |
| `fa-storage` | memory, redis, duckdb | Storage backends |
| `fa-server` | axum routes, middleware | HTTP layer |
| `fa-cli` | clap commands | Binary entry point |

**Benefits:**
- Faster compile times (fewer crate boundaries)
- Simpler dependency management
- Can split later if crate grows too large (>10k lines)

---

### 3. LLM Schema Design (JSON Schema for Structured Output)

**The Pattern:** Define output schema as JSON Schema, LLM returns conforming JSON.

**Schema Definition (Rust):**

```rust
// In fa-core/src/schema/analysis.rs

use serde::{Deserialize, Serialize};
use serde_json::json;

/// JSON Schema for sentiment analysis output
pub fn sentiment_schema() -> serde_json::Value {
    json!({
        "type": "object",
        "properties": {
            "results": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "index": {"type": "integer"},
                        "sentiment_score": {"type": "number", "minimum": 0, "maximum": 10},
                        "sentiment_category": {"type": "string", "enum": ["positive", "neutral", "negative"]},
                        "confidence": {"type": "number", "minimum": 0, "maximum": 1}
                    },
                    "required": ["index", "sentiment_score", "sentiment_category"]
                }
            }
        },
        "required": ["results"]
    })
}

/// Typed response struct (serde validates against schema)
#[derive(Debug, Deserialize)]
pub struct SentimentResponse {
    pub results: Vec<SentimentResult>,
}

#[derive(Debug, Deserialize)]
pub struct SentimentResult {
    pub index: usize,
    pub sentiment_score: f64,
    pub sentiment_category: String,
    #[serde(default)]
    pub confidence: Option<f64>,
}
```

**Usage in Adapter:**

```rust
impl LLMProvider for OllamaAdapter {
    async fn analyze_batch(&self, request: AnalysisRequest) -> Result<Vec<AnalysisResult>, LLMError> {
        let schema = sentiment_schema();

        let response = self.client
            .post(&format!("{}/v1/chat/completions", self.base_url))
            .json(&json!({
                "model": self.model,
                "messages": [...],
                "response_format": {
                    "type": "json_schema",
                    "json_schema": {
                        "strict": true,
                        "schema": schema
                    }
                }
            }))
            .send().await?;

        // Serde validates response matches schema
        let parsed: SentimentResponse = response.json().await?;

        Ok(parsed.results.into_iter().map(|r| AnalysisResult {
            index: r.index,
            raw_response: serde_json::to_value(&r).unwrap(),
            // ...
        }).collect())
    }
}
```

**Schema Registry Pattern:**

```rust
// All analysis schemas in one place
pub struct SchemaRegistry;

impl SchemaRegistry {
    pub fn sentiment() -> serde_json::Value { ... }
    pub fn churn_risk() -> serde_json::Value { ... }
    pub fn emotion() -> serde_json::Value { ... }
    pub fn pain_points() -> serde_json::Value { ... }

    /// Combined schema for full analysis
    pub fn full_analysis() -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "sentiment": Self::sentiment(),
                "churn": Self::churn_risk(),
                "emotions": Self::emotion(),
                "pain_points": Self::pain_points()
            }
        })
    }
}
```

---

### 4. Testing Strategy (Rust)

**Test Pyramid:**
```
         ╱╲
        ╱E2E╲        10% - Full pipeline with real Ollama
       ╱──────╲
      ╱ Integr ╲     20% - Multiple crates, mock LLM
     ╱──────────╲
    ╱   Unit     ╲   70% - Pure functions, no I/O
   ╱──────────────╲
```

**Unit Tests (in each module):**

```rust
// fa-core/src/schema/analysis.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sentiment_schema_validates_correct_response() {
        let schema = sentiment_schema();
        let valid = json!({"results": [{"index": 0, "sentiment_score": 7.5, "sentiment_category": "positive"}]});
        // Use jsonschema crate to validate
        assert!(jsonschema::is_valid(&schema, &valid));
    }
}
```

**Mock LLM Provider:**

```rust
// fa-pipeline/src/llm/mock.rs

pub struct MockLLMProvider {
    responses: HashMap<String, serde_json::Value>,
    call_count: AtomicUsize,
    latency_ms: u64,
}

impl MockLLMProvider {
    pub fn with_responses(responses: HashMap<String, serde_json::Value>) -> Self { ... }

    /// Deterministic responses based on input keywords
    pub fn deterministic() -> Self {
        Self::with_responses(hashmap!{
            "excellent" => json!({"sentiment_score": 9.0, "sentiment_category": "positive"}),
            "terrible" => json!({"sentiment_score": 2.0, "sentiment_category": "negative"}),
            "okay" => json!({"sentiment_score": 5.0, "sentiment_category": "neutral"}),
        })
    }
}

#[async_trait]
impl LLMProvider for MockLLMProvider {
    async fn analyze_batch(&self, request: AnalysisRequest) -> Result<Vec<AnalysisResult>, LLMError> {
        tokio::time::sleep(Duration::from_millis(self.latency_ms)).await;
        self.call_count.fetch_add(1, Ordering::SeqCst);

        // Return deterministic responses based on comment content
        Ok(request.comments.iter()
            .enumerate()
            .map(|(i, comment)| self.response_for(i, comment))
            .collect())
    }
}
```

**Integration Tests:**

```rust
// tests/integration/pipeline_test.rs

#[tokio::test]
async fn test_full_pipeline_with_mock_llm() {
    let mock_llm = Arc::new(MockLLMProvider::deterministic());
    let state = Arc::new(MemoryStateStore::new());

    let graph = GraphBuilder::new("test")
        .add_node(FileReaderNode::new("input"))
        .add_node(NormalizeNode::new("normalize"))
        .add_node(SentimentNode::new("sentiment"))
        .add_node(ParquetSinkNode::new("output"))
        .build();

    let ctx = ExecutionContext {
        llm_provider: Some(mock_llm.clone()),
        state_store: state,
        ..Default::default()
    };

    let result = graph.execute(&ctx, "fixtures/sample.csv").await;

    assert!(result.is_ok());
    assert_eq!(mock_llm.call_count(), 1);
}
```

**E2E Tests (require Ollama running):**

```rust
// tests/e2e/ollama_test.rs

#[tokio::test]
#[ignore] // Run with: cargo test --ignored
async fn test_real_ollama_sentiment() {
    let ollama = OllamaAdapter::new("localhost", 11434, "llama3.2");

    if !ollama.health_check().await {
        eprintln!("Ollama not running, skipping");
        return;
    }

    let request = AnalysisRequest {
        comments: StringArray::from(vec!["Great service!", "Terrible experience"]),
        language: "en".to_string(),
        analysis_schema: SchemaRegistry::sentiment(),
    };

    let results = ollama.analyze_batch(request).await.unwrap();

    assert_eq!(results.len(), 2);
    assert!(results[0].raw_response["sentiment_score"].as_f64().unwrap() > 5.0);
    assert!(results[1].raw_response["sentiment_score"].as_f64().unwrap() < 5.0);
}
```

**Test Fixtures (golden datasets):**

```
tests/
├── fixtures/
│   ├── sample_10.csv           # Quick tests
│   ├── sample_100.csv          # Standard tests
│   └── expected/
│       ├── sample_10.parquet   # Expected output
│       └── sample_100.parquet
└── golden/
    └── (symlink to blueprint/golden-datasets/)
```

**CI Configuration:**

```yaml
# .github/workflows/test.yml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable

      - name: Run unit tests
        run: cargo test --lib

      - name: Run integration tests
        run: cargo test --test '*'

      - name: Start Ollama
        run: |
          curl -fsSL https://ollama.ai/install.sh | sh
          ollama pull llama3.2:1b  # Smallest model for CI

      - name: Run E2E tests
        run: cargo test --ignored
```

---

## COMPLETE TYPE DEFINITIONS (From Blueprint)

### 5. Core Type Definitions

**Source:** `LLM_PROVIDER_CONTRACT.md`, `COMPUTE_GRAPH_SPEC.md`

```rust
/// Provider capabilities - discovered once at startup (LLM_PROVIDER_CONTRACT.md)
#[derive(Debug, Clone)]
pub struct ProviderCapabilities {
    pub provider_id: String,              // e.g., "ollama/llama3:8b"
    pub supports_structured_output: bool, // Native JSON schema enforcement
    pub supports_batch: bool,             // Native batch API (not loop)
    pub supports_streaming: bool,         // Token streaming
    pub supports_vision: bool,            // Image input
    pub max_context_tokens: u32,          // Context window size
    pub max_output_tokens: u32,           // Output limit
    pub tokens_per_second: f32,           // Throughput estimate (0 = unknown)
    pub cost_per_1k_input: f32,           // USD, 0 for local
    pub cost_per_1k_output: f32,          // USD, 0 for local
    pub supports_prompt_caching: bool,    // Anthropic/OpenAI prompt cache
}

/// Analysis request - Arrow-native (LLM_PROVIDER_CONTRACT.md)
pub struct AnalysisRequest {
    pub comments: StringArray,            // Arrow string array (zero-copy)
    pub language: String,                 // ISO 639-1 code
    pub analysis_schema: serde_json::Value, // JSON Schema for structured output
}

/// Analysis result per comment (LLM_PROVIDER_CONTRACT.md)
#[derive(Debug, Clone)]
pub struct AnalysisResult {
    pub index: usize,
    pub raw_response: serde_json::Value,  // Provider's raw JSON
    pub tokens_input: u32,
    pub tokens_output: u32,
    pub latency_ms: u64,
    pub provider_used: String,
}

/// Resource requirements for scheduling (COMPUTE_GRAPH_SPEC.md)
#[derive(Debug, Clone, Default)]
pub struct ResourceSpec {
    pub min_memory_mb: u32,               // Default: 256
    pub max_memory_mb: u32,               // Default: 4096
    pub cpu_cores: f32,                   // Default: 1.0
    pub gpu_required: bool,               // Default: false
    pub gpu_memory_mb: u32,               // Default: 0
    pub estimated_duration_ms: u64,       // For scheduling heuristics
}

/// Node execution result (COMPUTE_GRAPH_SPEC.md)
pub struct NodeResult {
    pub output: RecordBatch,
    pub metrics: HashMap<String, serde_json::Value>,
    pub duration_ms: u64,
    pub success: bool,
    pub error: Option<String>,
}

/// Execution context passed to all nodes (COMPUTE_GRAPH_SPEC.md)
pub struct ExecutionContext {
    // Core services
    pub cache: Arc<dyn Cache>,
    pub observability: Arc<dyn Observability>,
    pub state_store: Arc<dyn StateStore>,

    // Execution metadata
    pub graph_id: String,
    pub execution_id: String,
    pub batch_id: Option<String>,

    // Configuration
    pub language: String,                 // Default: "es"
    pub schema_config: Option<serde_json::Value>,

    // LLM access (injected)
    pub llm_provider: Option<Arc<dyn LLMProvider>>,

    // Callbacks
    pub on_progress: Option<Box<dyn Fn(&str, f32) + Send + Sync>>,
    pub is_cancelled: Option<Box<dyn Fn() -> bool + Send + Sync>>,
}

/// Routing strategy for LLM provider selection
#[derive(Debug, Clone, Copy, Default)]
pub enum RoutingStrategy {
    #[default]
    LocalFirst,    // Try local (Ollama/vLLM), fallback to cloud
    Cost,          // Cheapest available
    Latency,       // Fastest available
    Quality,       // Best model available
    Failover,      // Strict priority chain
}
```

---

### 6. Error Type Hierarchy

**Error codes map to thiserror variants:**

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum FeedbackArrowError {
    // FA-AUTH-XXX - Authentication
    #[error("FA-AUTH-001: Authentication failed")]
    AuthenticationFailed,
    #[error("FA-AUTH-002: API key invalid")]
    ApiKeyInvalid,
    #[error("FA-AUTH-003: API key expired")]
    ApiKeyExpired,

    // FA-RATE-XXX - Rate limiting
    #[error("FA-RATE-001: Rate limit exceeded")]
    RateLimitExceeded { retry_after_ms: u64 },
    #[error("FA-RATE-002: Daily quota exceeded")]
    DailyQuotaExceeded,

    // FA-VAL-XXX - Validation
    #[error("FA-VAL-001: Schema validation failed: {0}")]
    SchemaValidation(String),
    #[error("FA-VAL-002: Missing required column: {0}")]
    MissingColumn(String),

    // FA-LLM-XXX - LLM provider
    #[error("FA-LLM-001: No provider available")]
    NoProviderAvailable,
    #[error("FA-LLM-002: Provider timeout")]
    ProviderTimeout,
    #[error("FA-LLM-003: Provider returned invalid JSON")]
    InvalidProviderResponse,

    // FA-NODE-XXX - Compute node
    #[error("FA-NODE-001: Node execution failed: {0}")]
    NodeExecutionFailed(String),
    #[error("FA-NODE-002: Input schema mismatch")]
    InputSchemaMismatch,

    // FA-GRAPH-XXX - Graph execution
    #[error("FA-GRAPH-001: Cycle detected in graph")]
    CycleDetected,
    #[error("FA-GRAPH-002: Missing dependency: {0}")]
    MissingDependency(String),
}
```

---

### 7. Complete Trait Definitions

**From STATE_STORE_SPEC.md:**

```rust
/// Transient key-value state (duplicates, rate limiters, circuit breakers)
#[async_trait]
pub trait StateStore: Send + Sync {
    // Basic operations
    async fn get(&self, key: &str) -> Option<Vec<u8>>;
    async fn set(&self, key: &str, value: Vec<u8>, ttl: Option<Duration>) -> Result<()>;
    async fn delete(&self, key: &str) -> bool;
    async fn exists(&self, key: &str) -> bool;

    // Atomic operations
    async fn increment(&self, key: &str, delta: i64, ttl: Option<Duration>) -> i64;
    async fn compare_and_swap(&self, key: &str, expected: &[u8], new_value: Vec<u8>) -> bool;

    // Set operations (for duplicate detection)
    async fn add_to_set(&self, key: &str, values: &[String]) -> usize;
    async fn is_member(&self, key: &str, value: &str) -> bool;
    async fn set_members(&self, key: &str) -> HashSet<String>;

    // Batch operations
    async fn mget(&self, keys: &[&str]) -> HashMap<String, Option<Vec<u8>>>;
    async fn mset(&self, mapping: HashMap<String, Vec<u8>>, ttl: Option<Duration>) -> Result<()>;

    // Lifecycle
    async fn clear_namespace(&self, namespace: &str) -> usize;
    async fn get_stats(&self) -> HashMap<String, serde_json::Value>;
}

/// Persistent structured data (jobs, users, audit logs)
#[async_trait]
pub trait Persistence: Send + Sync {
    // CRUD
    async fn create(&self, table: &str, data: serde_json::Value, id: Option<&str>) -> Result<String>;
    async fn read(&self, table: &str, id: &str) -> Option<PersistenceRecord>;
    async fn update(&self, table: &str, id: &str, changes: serde_json::Value, version: Option<u32>) -> bool;
    async fn delete(&self, table: &str, id: &str, soft: bool) -> bool;

    // Query
    async fn find(&self, table: &str, query: serde_json::Value, options: QueryOptions) -> Vec<PersistenceRecord>;
    async fn find_one(&self, table: &str, query: serde_json::Value) -> Option<PersistenceRecord>;
    async fn count(&self, table: &str, query: serde_json::Value) -> usize;

    // Batch
    async fn create_many(&self, table: &str, records: Vec<serde_json::Value>) -> Vec<String>;
    async fn update_many(&self, table: &str, query: serde_json::Value, changes: serde_json::Value) -> usize;
    async fn delete_many(&self, table: &str, query: serde_json::Value, soft: bool) -> usize;

    // Schema
    async fn ensure_table(&self, table: &str, schema: HashMap<String, String>) -> Result<()>;
}

/// Secret storage (API keys, credentials)
#[async_trait]
pub trait SecretStore: Send + Sync {
    async fn get_secret(&self, name: &str) -> Result<String>;
    async fn set_secret(&self, name: &str, value: &str, secret_type: SecretType, expires_at: Option<DateTime<Utc>>) -> Result<()>;
    async fn delete_secret(&self, name: &str) -> bool;
    async fn rotate_secret(&self, name: &str, new_value: &str, grace_period: Duration) -> Result<()>;
    async fn list_secrets(&self, prefix: Option<&str>, secret_type: Option<SecretType>) -> Vec<SecretMetadata>;
    async fn secret_exists(&self, name: &str) -> bool;
}

/// Compute graph interface (COMPUTE_GRAPH_SPEC.md)
pub trait ComputeGraph: Send + Sync {
    fn graph_id(&self) -> &str;
    fn graph_version(&self) -> &str;

    fn add_node(&mut self, node: Box<dyn ComputeNode>) -> String;
    fn add_edge(&mut self, from_node: &str, to_node: &str) -> Result<()>;
    fn remove_node(&mut self, node_id: &str);

    fn get_node(&self, node_id: &str) -> Option<&dyn ComputeNode>;
    fn get_nodes(&self) -> Vec<&dyn ComputeNode>;
    fn get_edges(&self) -> Vec<GraphEdge>;

    fn get_entry_nodes(&self) -> Vec<String>;
    fn get_exit_nodes(&self) -> Vec<String>;
    fn get_execution_order(&self) -> Vec<Vec<String>>; // Parallelization levels

    fn validate(&self) -> Vec<String>;
    fn optimize(&self, strategy: OptimizationStrategy) -> Box<dyn ComputeGraph>;

    async fn execute(
        &self,
        input_data: HashMap<String, RecordBatch>,
        context: &ExecutionContext,
    ) -> Result<HashMap<String, RecordBatch>>;

    fn to_dict(&self) -> serde_json::Value;
    fn visualize(&self) -> String; // Mermaid diagram
}
```

---

### 8. All 15 Compute Nodes

**From COMPUTE_NODES_SPEC.md:**

| Category | Node ID | Rust Struct | Purpose |
|----------|---------|-------------|---------|
| **Source** | | | |
| source | `file_reader` | `FileReaderNode` | Load CSV/XLSX/Parquet → Arrow |
| **Transform** | | | |
| transform | `normalize_text` | `NormalizeTextNode` | Unicode NFC, lowercase, strip |
| transform | `deduplicate` | `DeduplicateNode` | SHA256 hash grouping |
| transform | `word_count` | `WordCountNode` | Text metrics, length categories |
| **Enrich** | | | |
| enrich | `local_sentiment` | `LocalSentimentNode` | Lexicon-based sentiment (pre-LLM) |
| enrich | `nps_category` | `NPSCategoryNode` | Promoter/Passive/Detractor |
| enrich | `pain_point_classifier` | `PainPointClassifierNode` | 21 category taxonomy |
| enrich | `behavioral_flags` | `BehavioralFlagsNode` | Exit threat, competitor, etc. |
| enrich | `review_priority` | `ReviewPriorityNode` | 0-100 triage score |
| **LLM** | | | |
| llm | `sentiment` | `LLMSentimentNode` | AI sentiment 0-10 |
| llm | `churn_risk` | `LLMChurnRiskNode` | Churn score 0-100 |
| llm | `emotion` | `LLMEmotionNode` | 7 emotion categories |
| llm | `discrepancy` | `LLMDiscrepancyNode` | Resolve sentiment/NPS mismatches |
| **Sink** | | | |
| sink | `parquet` | `ParquetExportNode` | Parquet with zstd compression |
| sink | `csv` | `CSVExportNode` | CSV with UTF-8-BOM |

---

### 9. LLM Operational Patterns

```rust
/// Performance tuning defaults
pub struct LLMPerformanceConfig {
    pub batch_size: usize,               // 50 comments per batch
    pub max_concurrent_batches: usize,   // 4 parallel batches
    pub timeout_seconds: u64,            // 120 per-batch timeout
    pub retry_attempts: u32,             // 3 retries on failure
    pub retry_backoff_factor: f32,       // 2.0 exponential backoff
}

/// Batch size guidelines by provider
const BATCH_SIZES: &[(&str, usize)] = &[
    ("ollama_7b", 10),    // ~2GB VRAM per batch
    ("ollama_13b", 5),    // ~4GB VRAM per batch
    ("ollama_70b", 2),    // ~20GB VRAM per batch
    ("vllm", 50),         // Continuous batching
    ("openai", 50),       // Stay under TPM limits
    ("anthropic", 30),    // More conservative
];

/// Cache key format for LLM results
fn cache_key(comment_hash: &str, language: &str, schema_hash: &str) -> String {
    format!("llm:{}:{}:{}", comment_hash, language, schema_hash)
}
```

---

### 10. Configuration Schema (TOML)

```toml
# ~/.feedback-arrow/config.toml

[server]
host = "0.0.0.0"
port = 8000
workers = 4

[database]
url = "duckdb:///./feedback_arrow.duckdb"
pool_size = 5

[cache]
backend = "memory"  # memory | redis | disk
memory_max_size_mb = 256

[providers]
default = "ollama"
routing_strategy = "local_first"  # local_first | cost | latency | quality | failover

[providers.ollama]
enabled = true
priority = 1
endpoint = "http://localhost:11434"
model = "llama3.2"

[providers.openai]
enabled = false
priority = 10
model = "gpt-4o-mini"
api_key = "${OPENAI_API_KEY}"

[analysis]
batch_size = 50
default_language = "es"
enable_checkpointing = true

[export]
default_format = "parquet"
parquet_compression = "zstd"
```

---

### 11. Multi-Tenancy

```rust
#[derive(Debug, Clone)]
pub struct TenantContext {
    pub org_id: String,           // org_01hqx5k8n7gm4r2p3j6c9b0a
    pub workspace_id: String,     // ws_01hqx5k8n7gm4r2p3j6c9b0a
    pub project_id: Option<String>,
    pub tier: Tier,               // Free, Pro, Enterprise
    pub quotas: TenantQuotas,
}

#[derive(Debug, Clone, Copy)]
pub enum Tier {
    Free,       // 10/min, 1k rows/day, 100MB, 1 concurrent
    Pro,        // 100/min, 100k rows/day, 10GB, 5 concurrent
    Enterprise, // 1000/min, unlimited, 1TB, 50 concurrent
}
```

---

### 12. Language Pack Loading

```rust
/// Language pack structure (from LANGUAGE_PACK_SPEC.md)
#[derive(Debug, Deserialize)]
pub struct LanguagePack {
    pub language_code: String,    // "es", "en"
    pub sentiment_lexicon: HashMap<String, f64>,
    pub negation_words: Vec<String>,
    pub intensifiers: Vec<String>,
    pub pain_point_keywords: HashMap<String, Vec<String>>,
    pub churn_patterns: ChurnPatterns,
}

/// Load from embedded resources or filesystem
pub fn load_language_pack(language: &str) -> Result<LanguagePack> {
    let path = format!("language_packs/{}.json", language);
    let content = std::fs::read_to_string(&path)?;
    Ok(serde_json::from_str(&content)?)
}
```

---

## CRITICAL DECISIONS (Updated 2025-12-20)

### 13. LLM Backend: llama-server (NOT Ollama)

**Rationale:**
- Ollama adds dashboard/management overhead we don't need
- llama-server (llama.cpp) is lighter, same OpenAI-compatible API
- Our sentiment analysis business model doesn't need model switching UI
- Single model deployment = simpler service coupling

**Service Coupling Options:**

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **External Service** | Simplest, independent scaling | Separate process management | **Default for production** |
| **Managed Subprocess** | App controls lifecycle | Complex error handling | For single-binary deployment |
| **Docker Sidecar** | Clean separation, easy orchestration | Requires Docker | For containerized deployments |
| **Embedded (FFI)** | No HTTP overhead | Complex build, large binary | Only if latency critical |

**Chosen Approach:** Managed Subprocess (single-binary deployment)

---

### 14. Subprocess Architecture

```
┌─────────────────────────────────────────────────────┐
│                 feedback-arrow                       │
│  ┌─────────────────────────────────────────────────┐│
│  │ LlamaServerManager                              ││
│  │  - spawn_server()                               ││
│  │  - health_check_loop()                          ││
│  │  - graceful_shutdown()                          ││
│  └─────────────────────────────────────────────────┘│
│                        │                             │
│                        ▼ HTTP :8080                  │
│  ┌─────────────────────────────────────────────────┐│
│  │ llama-server (child process)                    ││
│  │  - Loaded model: sentiment-llama-3b.gguf        ││
│  │  - Context: 4096                                ││
│  │  - Threads: auto                                ││
│  └─────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────┘
```

**Subprocess Lifecycle:**

```rust
pub struct LlamaServerManager {
    config: LlamaServerConfig,
    process: Option<Child>,
    client: Client,
}

pub struct LlamaServerConfig {
    /// Path to llama-server binary (or "llama-server" for PATH lookup)
    pub binary_path: PathBuf,
    /// Path to GGUF model file
    pub model_path: PathBuf,
    /// Port to bind (default: 8080)
    pub port: u16,
    /// Context size (default: 4096)
    pub context_size: u32,
    /// CPU threads (default: auto-detect)
    pub threads: Option<u32>,
    /// GPU layers to offload (default: 0 for CPU-only)
    pub gpu_layers: u32,
    /// Startup timeout in seconds (default: 60)
    pub startup_timeout_secs: u64,
}

impl LlamaServerManager {
    pub async fn start(&mut self) -> Result<(), LLMError> {
        // 1. Spawn llama-server process
        let child = Command::new(&self.config.binary_path)
            .args([
                "-m", self.config.model_path.to_str().unwrap(),
                "--port", &self.config.port.to_string(),
                "-c", &self.config.context_size.to_string(),
                "-ngl", &self.config.gpu_layers.to_string(),
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true)  // CRITICAL: cleanup on panic
            .spawn()?;

        self.process = Some(child);

        // 2. Wait for health check (with timeout)
        let deadline = Instant::now() + Duration::from_secs(self.config.startup_timeout_secs);
        loop {
            if Instant::now() > deadline {
                self.stop().await;
                return Err(LLMError::Timeout(self.config.startup_timeout_secs * 1000));
            }

            if self.health_check().await {
                return Ok(());
            }

            tokio::time::sleep(Duration::from_millis(500)).await;
        }
    }

    pub async fn stop(&mut self) {
        if let Some(mut process) = self.process.take() {
            // Graceful: SIGTERM, wait 5s, then SIGKILL
            let _ = process.start_kill();
            let _ = tokio::time::timeout(
                Duration::from_secs(5),
                process.wait()
            ).await;
        }
    }

    async fn health_check(&self) -> bool {
        self.client
            .get(format!("http://localhost:{}/health", self.config.port))
            .send().await
            .map(|r| r.status().is_success())
            .unwrap_or(false)
    }
}
```

---

### 15. LlamaServerAdapter (Primary - replaces OllamaAdapter)

```rust
pub struct LlamaServerAdapter {
    client: Client,
    base_url: String,  // Default: http://localhost:8080
    model: String,     // Loaded model name (informational)
}

impl LlamaServerAdapter {
    pub fn new(base_url: &str) -> Self { ... }

    // Health check uses /health endpoint (not /api/tags like Ollama)
    async fn health_check(&self) -> bool {
        self.client.get(&format!("{}/health", self.base_url))
            .send().await
            .map(|r| r.status().is_success())
            .unwrap_or(false)
    }
}
```

---

### 16. Subprocess Configuration (TOML)

```toml
[llm]
# Subprocess mode (default for single-binary deployment)
mode = "subprocess"  # "subprocess" | "external"

[llm.subprocess]
binary_path = "llama-server"  # PATH lookup, or absolute path
model_path = "./models/sentiment-llama-3b.gguf"
port = 8080
context_size = 4096
threads = 0  # 0 = auto-detect
gpu_layers = 0  # 0 = CPU only
startup_timeout_secs = 60

[llm.external]
# Alternative: connect to running server
url = "http://localhost:8080"
```

---

### 17. Binary Discovery Strategy

```rust
fn find_llama_server() -> Result<PathBuf, LLMError> {
    // 1. Check config path
    if let Some(path) = config.binary_path {
        if path.exists() { return Ok(path); }
    }

    // 2. Check alongside executable
    if let Ok(exe) = std::env::current_exe() {
        let sibling = exe.parent().unwrap().join("llama-server");
        if sibling.exists() { return Ok(sibling); }
    }

    // 3. Check PATH
    if let Ok(which) = which::which("llama-server") {
        return Ok(which);
    }

    // 4. Check common locations
    for path in ["/usr/local/bin/llama-server", "/usr/bin/llama-server"] {
        if Path::new(path).exists() { return Ok(PathBuf::from(path)); }
    }

    Err(LLMError::ProviderConnectionFailed("llama-server binary not found".into()))
}
```

---

### 18. Graceful Shutdown

```rust
// In main.rs
async fn main() {
    let mut llm_manager = LlamaServerManager::new(config);
    llm_manager.start().await?;

    // Register shutdown handler
    let llm_for_shutdown = llm_manager.clone();
    tokio::spawn(async move {
        tokio::signal::ctrl_c().await.ok();
        llm_for_shutdown.stop().await;
    });

    // Run application...
    run_app(&llm_manager).await;

    // Cleanup on normal exit
    llm_manager.stop().await;
}
```

---

### 19. Trade-offs: Subprocess vs External Service

| Aspect | Subprocess | External |
|--------|------------|----------|
| Deployment | Single binary + model | Separate llama-server |
| Startup | App manages lifecycle | Pre-started service |
| Scaling | 1:1 with app | Independent scaling |
| Failure | App restarts llama-server | Separate monitoring |
| Resource control | App controls all | Separate resource limits |
| Development | More complex | Simpler |

**When to use Subprocess:**
- Single-machine deployment
- Embedded/appliance-style deployment
- When you want one binary to rule them all

**When to use External:**
- Kubernetes/containerized deployment
- Multiple app instances sharing one LLM
- Need independent scaling
