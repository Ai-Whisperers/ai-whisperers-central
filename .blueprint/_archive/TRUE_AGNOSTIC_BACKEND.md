# True Agnostic Backend Architecture

**Purpose:** Eliminate single-vendor dependencies at every critical layer
**Strategy:** Make vendors believe they're locking us in while we become the indispensable integration point
**Principle:** Own the contracts, swap the implementations

---

## STRATEGIC GOAL

```
Customers depend on:        Vendors become:
- Our schema (v1.x.x)       - Swappable commodities
- Our language packs        - Competing for our business
- Our export formats        - Unable to replace us
- Our API contracts         - Interchangeable backends
```

---

## 1. LLM PROVIDER ABSTRACTION

### Current State (VULNERABLE)

```
OpenAI GPT-4o-mini (SINGLE POINT OF FAILURE)
  |
  +-- No fallback
  +-- No local option
  +-- Price changes = cost explosion
  +-- Rate limit changes = service degradation
```

### Target State (RESILIENT)

```
ILLMProvider Interface
  |
  +-- OpenAIProvider (gpt-4o-mini, gpt-4o, o1)
  +-- AnthropicProvider (claude-3-haiku, claude-3-sonnet)
  +-- GoogleProvider (gemini-1.5-flash, gemini-1.5-pro)
  +-- LocalProvider (ollama/llama3, vllm/mistral)
  +-- RouterProvider (cost/latency/quality routing)
```

### Interface Contract

```python
class ILLMProvider(Protocol):
    """Vendor-agnostic LLM interface"""

    async def analyze_batch(
        self,
        comments: List[str],
        language: str,
        schema: AnalysisSchema
    ) -> List[AnalysisResult]:
        """Batch analysis with structured output"""
        ...

    async def analyze_single(
        self,
        comment: str,
        language: str,
        schema: AnalysisSchema
    ) -> AnalysisResult:
        """Single comment analysis"""
        ...

    def estimate_cost(
        self,
        comments: List[str]
    ) -> CostEstimate:
        """Pre-flight cost estimation"""
        ...

    def get_capabilities(self) -> ProviderCapabilities:
        """What this provider supports"""
        ...

    @property
    def provider_id(self) -> str:
        """Unique identifier for routing/logging"""
        ...
```

### Provider Capabilities

```python
@dataclass
class ProviderCapabilities:
    supports_structured_output: bool  # JSON schema enforcement
    supports_batch: bool              # Native batching
    supports_streaming: bool          # Token streaming
    max_context_tokens: int           # Context window
    max_output_tokens: int            # Output limit
    languages: List[str]              # Supported languages
    latency_p50_ms: int              # Typical latency
    cost_per_1k_input: float         # Input token cost
    cost_per_1k_output: float        # Output token cost
    rate_limit_rpm: int              # Requests per minute
    rate_limit_tpm: int              # Tokens per minute
```

### Router Strategy

```python
class LLMRouter:
    """Intelligent provider routing"""

    strategies = {
        "cost_optimized": route_by_lowest_cost,
        "latency_optimized": route_by_lowest_latency,
        "quality_optimized": route_by_highest_quality,
        "balanced": route_by_score,
        "failover": route_with_fallback_chain,
    }

    def route(
        self,
        request: AnalysisRequest,
        strategy: str = "balanced"
    ) -> ILLMProvider:
        """Select optimal provider for request"""
        ...

    def fallback_chain(self) -> List[str]:
        """Priority order for failover"""
        return [
            "openai",      # Primary (best structured output)
            "anthropic",   # Secondary (best reasoning)
            "google",      # Tertiary (best multilingual)
            "local",       # Emergency (no cost, slower)
        ]
```

### Configuration

```python
LLM_PROVIDERS = {
    "openai": {
        "enabled": True,
        "api_key": "${OPENAI_API_KEY}",
        "model": "gpt-4o-mini",
        "priority": 1,
        "max_budget_daily": 10.0,
    },
    "anthropic": {
        "enabled": True,
        "api_key": "${ANTHROPIC_API_KEY}",
        "model": "claude-3-haiku-20240307",
        "priority": 2,
        "max_budget_daily": 10.0,
    },
    "google": {
        "enabled": False,  # Enable when needed
        "api_key": "${GOOGLE_AI_API_KEY}",
        "model": "gemini-1.5-flash",
        "priority": 3,
    },
    "local": {
        "enabled": True,
        "endpoint": "http://localhost:11434",  # Ollama
        "model": "llama3:8b",
        "priority": 99,  # Emergency fallback
    },
}

LLM_ROUTING_STRATEGY = "balanced"  # cost_optimized | latency_optimized | quality_optimized | balanced | failover
```

---

## 2. EXPORT FORMAT ABSTRACTION

### Current State (VULNERABLE)

```
Google Sheets (SINGLE POINT OF FAILURE)
  |
  +-- Excel removed (no alternative)
  +-- OAuth = Google controls access
  +-- API quotas can change
  +-- Proprietary format lock-in
```

### Target State (RESILIENT)

```
IExporter Interface
  |
  +-- ArrowExporter (PRIMARY - open standard)
  |     +-- Parquet files (columnar, compressed)
  |     +-- Arrow IPC (streaming, zero-copy)
  |     +-- CSV (universal fallback)
  |
  +-- CloudExporter (CONVENIENCE WRAPPERS)
        +-- GoogleSheetsExporter
        +-- OneDriveExporter (future)
        +-- NotionExporter (future)
```

### Interface Contract

```python
class IExporter(Protocol):
    """Vendor-agnostic export interface"""

    def export(
        self,
        data: pa.Table,  # Arrow Table as canonical format
        options: ExportOptions
    ) -> ExportResult:
        """Export data to target format"""
        ...

    def get_supported_formats(self) -> List[str]:
        """Available output formats"""
        ...

    def validate_options(
        self,
        format: str,
        options: Dict
    ) -> ValidationResult:
        """Pre-flight validation"""
        ...

    @property
    def exporter_id(self) -> str:
        """Unique identifier"""
        ...
```

### Export Formats Priority

```python
EXPORT_FORMATS = {
    # PRIMARY - Open Standards (always available)
    "parquet": {
        "exporter": "arrow",
        "description": "Columnar, compressed, any tool can read",
        "priority": 1,
        "always_available": True,
    },
    "arrow_ipc": {
        "exporter": "arrow",
        "description": "Streaming, zero-copy, inter-process",
        "priority": 2,
        "always_available": True,
    },
    "csv": {
        "exporter": "arrow",
        "description": "Universal fallback, UTF-8 BOM",
        "priority": 3,
        "always_available": True,
    },

    # SECONDARY - Cloud Wrappers (optional convenience)
    "google_sheets": {
        "exporter": "google",
        "description": "Collaborative spreadsheet",
        "priority": 10,
        "requires": ["GOOGLE_OAUTH_TOKEN"],
    },
    "excel_online": {
        "exporter": "microsoft",
        "description": "OneDrive spreadsheet",
        "priority": 11,
        "requires": ["MICROSOFT_OAUTH_TOKEN"],
    },
}
```

### Arrow as Canonical Internal Format

```python
# ALL internal processing uses Arrow Tables
# Export is always Arrow -> Target Format

def process_feedback(file_path: str) -> pa.Table:
    """Processing always returns Arrow Table"""
    ...

def export_results(
    data: pa.Table,
    format: str = "parquet"
) -> ExportResult:
    """Arrow Table -> Any format"""
    exporter = get_exporter(format)
    return exporter.export(data, options)
```

---

## 3. TUNNEL/EDGE ABSTRACTION

### Current State (VULNERABLE)

```
Cloudflare Tunnel (SINGLE POINT OF FAILURE)
  |
  +-- DDoS protection tied to vendor
  +-- Auth tied to vendor
  +-- No self-hosted option
  +-- Pricing can change
```

### Target State (RESILIENT)

```
ITunnel Interface
  |
  +-- CloudflareTunnel (managed, DDoS protection)
  +-- TailscaleTunnel (self-hosted mesh VPN)
  +-- WireGuardTunnel (self-hosted, lightweight)
  +-- NgrokTunnel (development, quick setup)
```

### Interface Contract

```python
class ITunnel(Protocol):
    """Vendor-agnostic tunnel interface"""

    async def connect(self) -> TunnelConnection:
        """Establish tunnel connection"""
        ...

    async def disconnect(self) -> None:
        """Close tunnel"""
        ...

    def get_public_url(self) -> str:
        """Public endpoint URL"""
        ...

    def get_health(self) -> TunnelHealth:
        """Connection health status"""
        ...

    @property
    def tunnel_id(self) -> str:
        """Unique identifier"""
        ...
```

### Tunnel Capabilities

```python
@dataclass
class TunnelCapabilities:
    provides_ddos_protection: bool
    provides_waf: bool
    provides_auth: bool
    provides_rate_limiting: bool
    supports_websocket: bool
    supports_grpc: bool
    max_connections: int
    bandwidth_limit_mbps: Optional[int]
    requires_client_install: bool
    self_hostable: bool
```

### Configuration

```python
TUNNEL_PROVIDERS = {
    "cloudflare": {
        "enabled": True,
        "token": "${CLOUDFLARE_TUNNEL_TOKEN}",
        "provides": ["ddos", "waf", "auth", "rate_limiting"],
        "priority": 1,
    },
    "tailscale": {
        "enabled": False,
        "auth_key": "${TAILSCALE_AUTH_KEY}",
        "provides": ["mesh_vpn", "acl"],
        "priority": 2,
        "self_hosted": True,
    },
    "wireguard": {
        "enabled": False,
        "config_path": "/etc/wireguard/wg0.conf",
        "provides": ["vpn"],
        "priority": 3,
        "self_hosted": True,
    },
}

# If tunnel provider doesn't provide these, implement internally
EDGE_REQUIREMENTS = {
    "rate_limiting": "required",   # Cloudflare OR internal
    "auth": "required",            # Cloudflare OR internal
    "ddos": "recommended",         # Cloudflare only
    "waf": "recommended",          # Cloudflare only
}
```

---

## 4. SCHEMA VERSIONING STRATEGY

### Current State (VULNERABLE)

```
36 columns documented but:
  +-- No version number
  +-- No breaking change protocol
  +-- No migration path
  +-- Clients can break silently
```

### Target State (RESILIENT)

```
Semantic Versioned Schema
  |
  +-- v1.0.0 - Initial 36 columns
  +-- v1.1.0 - Added columns (backward compatible)
  +-- v2.0.0 - Breaking changes (migration required)
```

### Schema Version Contract

```python
SCHEMA_VERSION = "1.0.0"  # Semantic versioning

@dataclass
class SchemaVersion:
    major: int  # Breaking changes
    minor: int  # New columns (backward compatible)
    patch: int  # Bug fixes (no schema change)

    def is_compatible(self, other: "SchemaVersion") -> bool:
        """Check if schemas are compatible"""
        return self.major == other.major

# Every export includes version metadata
EXPORT_METADATA = {
    "schema_version": "1.0.0",
    "schema_url": "https://docs.example.com/schema/v1",
    "generated_at": "2025-12-13T10:00:00Z",
    "generator": "feedback-analyzer",
    "generator_version": "3.10.0",
}
```

### Column Registry

```python
# Centralized column definitions with version tracking
COLUMN_REGISTRY = {
    # v1.0.0 - Original columns
    "user_score": {
        "type": "float",
        "range": [0, 10],
        "nullable": False,
        "since": "1.0.0",
        "description": "User-provided rating",
    },
    "customer_comment": {
        "type": "string",
        "nullable": False,
        "since": "1.0.0",
        "description": "Original feedback text",
    },
    # ... 34 more columns

    # v1.1.0 - New columns (backward compatible)
    "provider_used": {
        "type": "string",
        "nullable": True,
        "since": "1.1.0",
        "description": "LLM provider that processed this row",
    },

    # v2.0.0 - Breaking changes
    # (would require migration guide)
}

def get_columns_for_version(version: str) -> List[str]:
    """Get columns available in a schema version"""
    target = SchemaVersion.parse(version)
    return [
        name for name, spec in COLUMN_REGISTRY.items()
        if SchemaVersion.parse(spec["since"]) <= target
    ]
```

### Migration Protocol

```python
# When breaking changes are needed:

MIGRATIONS = {
    "1.0.0 -> 2.0.0": {
        "description": "Renamed emotion columns to standardized format",
        "changes": [
            {"type": "rename", "from": "satisfaccion", "to": "emotion_satisfaction"},
            {"type": "rename", "from": "frustracion", "to": "emotion_frustration"},
        ],
        "migration_script": "migrations/v1_to_v2.py",
        "deprecation_date": "2026-06-01",
        "removal_date": "2026-12-01",
    }
}
```

---

## 5. LANGUAGE PACK PATTERN

### Current State (VULNERABLE)

```
Hard-coded Spanish:
  +-- Lexicons embedded in code
  +-- Emotion categories in Spanish
  +-- Keyword patterns Spanish-only
  +-- Market limited to 500M speakers
```

### Target State (RESILIENT)

```
Language Pack Architecture
  |
  +-- es (Spanish) - Current, production-ready
  +-- en (English) - 1.5B speakers, highest ROI
  +-- pt (Portuguese) - 250M speakers, LATAM synergy
  +-- fr (French) - 300M speakers, Africa growth
```

### Language Pack Interface

```python
class ILanguagePack(Protocol):
    """Vendor-agnostic language support"""

    @property
    def language_code(self) -> str:
        """ISO 639-1 code (es, en, pt, fr)"""
        ...

    def get_sentiment_lexicon(self) -> Dict[str, float]:
        """Word -> sentiment score mapping"""
        ...

    def get_emotion_categories(self) -> List[str]:
        """Emotion category names in this language"""
        ...

    def get_modifiers(self) -> ModifierConfig:
        """Negation, intensifiers, etc."""
        ...

    def get_churn_patterns(self) -> Dict[str, List[str]]:
        """Exit threat, competitor mention patterns"""
        ...

    def get_pain_point_keywords(self) -> Dict[str, List[str]]:
        """Category -> keyword patterns"""
        ...
```

### Language Pack Structure

```
language_packs/
  |-- es/
  |     +-- lexicon.json        # 5000+ Spanish sentiment words
  |     +-- emotions.json       # 7 emotion categories
  |     +-- modifiers.json      # Negation, intensifiers
  |     +-- churn_patterns.json # Exit threats, competitors
  |     +-- pain_points.json    # 21 category keywords
  |     +-- config.json         # Thresholds, weights
  |
  |-- en/
  |     +-- lexicon.json        # English sentiment words
  |     +-- emotions.json       # Same 7 categories, English names
  |     +-- modifiers.json      # "not", "very", "extremely"
  |     +-- churn_patterns.json # "cancel", "switch to"
  |     +-- pain_points.json    # English keywords
  |     +-- config.json         # May have different thresholds
  |
  |-- pt/
  |     +-- ... (Portuguese pack)
```

### Language Detection & Routing

```python
class LanguageRouter:
    """Auto-detect and route to appropriate pack"""

    def detect_language(self, text: str) -> str:
        """Detect language from text"""
        # Use langdetect, fasttext, or similar
        ...

    def get_pack(self, language: str) -> ILanguagePack:
        """Get language pack for processing"""
        ...

    def analyze_with_auto_detect(
        self,
        comment: str
    ) -> Tuple[str, AnalysisResult]:
        """Detect language and analyze"""
        lang = self.detect_language(comment)
        pack = self.get_pack(lang)
        result = self.analyze_with_pack(comment, pack)
        return lang, result
```

### Configuration

```python
LANGUAGE_CONFIG = {
    "default": "es",
    "auto_detect": True,
    "supported": ["es", "en", "pt"],
    "fallback": "en",  # If detection fails

    "packs": {
        "es": {
            "enabled": True,
            "version": "1.0.0",
            "lexicon_size": 5000,
        },
        "en": {
            "enabled": True,
            "version": "1.0.0",
            "lexicon_size": 8000,
        },
        "pt": {
            "enabled": False,  # Future
            "version": "0.1.0",
        },
    }
}
```

---

## 6. COMPUTE ABSTRACTION

> **⚠️ RAY IS NEGLIGIBLE:** For self-deployed VM services processing typical feedback datasets (50-150MB, 125k rows), Ray is unnecessary—Polars processes in <2 seconds with Rust/Rayon parallelism. Ray introduces Anyscale vendor risk and complexity. See `BLINDSPOTS.md` Section "Why Ray is Negligible" and `STRATEGY.md` "DECISION: Avoid Ray" for full rationale.

### Risk Assessment

```
Ray (AVOID - Anyscale Vendor Risk)
  |
  +-- Anyscale controls ecosystem
  +-- Cloud offerings push vendor lock-in
  +-- License change risk (BSL/SSPL precedent)
  +-- Telemetry phones home by default
  +-- 50+ dependencies cause version conflicts
```

### Target State (RESILIENT)

```
IComputeOrchestrator Interface (Prefer Top to Bottom)
  |
  +-- LocalOrchestrator (Polars + httpx/anyio - DEFAULT)
  +-- DataFusionOrchestrator (query optimization)
  +-- DaskOrchestrator (scale-out if needed)
  +-- RayOrchestrator (ONLY if customer demands with risk acceptance)
```

### Interface Contract

```python
class IComputeOrchestrator(Protocol):
    """Vendor-agnostic compute orchestration"""

    async def submit_batch(
        self,
        func: Callable,
        items: List[Any],
        batch_size: int
    ) -> List[Future]:
        """Submit batch processing job"""
        ...

    async def gather_results(
        self,
        futures: List[Future]
    ) -> List[Any]:
        """Collect results from futures"""
        ...

    def get_cluster_status(self) -> ClusterStatus:
        """Current cluster state"""
        ...

    def scale(self, workers: int) -> None:
        """Scale cluster up/down"""
        ...
```

---

## 7. CACHE ABSTRACTION

### Current State (PLANNED RISK)

```
Redpanda (POTENTIAL LOCK-IN)
  |
  +-- Kafka-compatible (good)
  +-- Premium features could lock
  +-- No alternative defined
```

### Target State (RESILIENT)

```
ICache + IEventStream Interfaces
  |
  +-- Cache: Redis | Valkey | KeyDB | DragonflyDB
  +-- Events: Redpanda | Kafka | NATS | RabbitMQ
```

### Configuration

```python
CACHE_PROVIDERS = {
    "redis": {
        "enabled": True,
        "url": "redis://localhost:6379",
        "priority": 1,
    },
    "valkey": {  # Redis fork, fully compatible
        "enabled": False,
        "url": "valkey://localhost:6379",
        "priority": 2,
    },
    "dragonfly": {  # Redis-compatible, higher performance
        "enabled": False,
        "url": "redis://localhost:6379",
        "priority": 3,
    },
}

EVENT_PROVIDERS = {
    "redpanda": {
        "enabled": True,
        "brokers": ["localhost:9092"],
        "priority": 1,
    },
    "kafka": {  # Fully compatible fallback
        "enabled": False,
        "brokers": ["localhost:9092"],
        "priority": 2,
    },
    "nats": {  # Lightweight alternative
        "enabled": False,
        "url": "nats://localhost:4222",
        "priority": 3,
    },
}
```

---

## 8. IMPLEMENTATION STEPS (INVARIANT ORDER)

Steps are ordered by **dependency**, not time. Each step unlocks the next.

### Step 1: Data Foundation (PREREQUISITE FOR ALL)

**Unlocks:** All subsequent steps depend on Arrow as canonical format

```
[ ] 1.1 Arrow as internal format (pa.Table everywhere)
[ ] 1.2 Schema versioning (v1.0.0 on all exports)
[ ] 1.3 Column registry (centralized definitions)
[ ] 1.4 Export format abstraction (IExporter interface)
```

**Invariant:** Cannot proceed without Arrow foundation - all interfaces expect pa.Table

### Step 2: Language Abstraction (PREREQUISITE FOR MULTI-MARKET)

**Unlocks:** Multi-language support, market expansion

```
[ ] 2.1 ILanguagePack interface definition
[ ] 2.2 Extract Spanish to language pack structure
[ ] 2.3 Language detection routing
[ ] 2.4 English language pack (optional, enables EN market)
```

**Invariant:** Language packs must exist before LLM prompts can be language-agnostic

### Step 3: LLM Abstraction (PREREQUISITE FOR VENDOR FLEXIBILITY)

**Unlocks:** Multi-provider routing, cost optimization, failover

**Depends on:** Step 2 (language packs for prompt templates)

```
[ ] 3.1 ILLMProvider interface definition
[ ] 3.2 OpenAI implementation (wrap current code)
[ ] 3.3 Anthropic implementation
[ ] 3.4 Local/Ollama implementation
[ ] 3.5 LLMRouter with strategy selection
[ ] 3.6 Fallback chain configuration
```

**Invariant:** All providers must implement same interface before router can work

### Step 4: Infrastructure Abstraction (PREREQUISITE FOR DEPLOYMENT FLEXIBILITY)

**Unlocks:** Self-hosted options, cloud portability

**Depends on:** Step 1 (Arrow format for ICache data)

```
[ ] 4.1 ITunnel interface definition
[ ] 4.2 Cloudflare implementation (wrap current)
[ ] 4.3 Tailscale/WireGuard implementations
[ ] 4.4 ICache interface definition
[ ] 4.5 Redis implementation (wrap current)
[ ] 4.6 IEventStream interface definition
[ ] 4.7 Redpanda implementation
```

**Invariant:** Interfaces must be defined before implementations can be swapped

### Step 5: Compute Abstraction (PREREQUISITE FOR SCALE)

**Unlocks:** Distributed processing, HPC deployment

**Depends on:** Step 1 (Arrow for zero-copy), Step 4 (ICache for state)

```
[ ] 5.1 IComputeOrchestrator interface definition
[ ] 5.2 LocalOrchestrator (single-machine baseline)
[ ] 5.3 RayOrchestrator implementation
[ ] 5.4 IResourcePool interface
[ ] 5.5 Resource discovery (auto-detect cores/memory/nodes)
[ ] 5.6 ResourceMultiplier configuration
```

**Invariant:** Local orchestrator must work before distributed can be tested

### Step 6: Validation (PREREQUISITE FOR PRODUCTION)

**Unlocks:** Confidence in provider switching, deployment safety

**Depends on:** All previous steps

```
[ ] 6.1 Provider switching tests (swap without code change)
[ ] 6.2 Failover scenario tests (provider down -> fallback works)
[ ] 6.3 Schema migration tests (v1 -> v2 path)
[ ] 6.4 Performance benchmarks (baseline for each provider)
[ ] 6.5 Cost comparison matrix (provider x workload)
```

**Invariant:** Cannot deploy to production without validation passing

### Dependency Graph

```
Step 1 (Data Foundation)
    |
    +---> Step 2 (Language) ---> Step 3 (LLM)
    |                                |
    +---> Step 4 (Infrastructure) <--+
              |
              v
         Step 5 (Compute)
              |
              v
         Step 6 (Validation)
```

---

## 9. STRATEGIC OUTCOMES

### What Vendors See

```
"They're deeply integrated with our platform"
"High switching costs"
"Locked into our ecosystem"
```

### What We Actually Have

```
- Every vendor is behind an interface
- Switching cost: change config, not code
- Multiple providers competing for our business
- Leverage to negotiate better terms
- Customers depend on OUR schema, not vendor format
```

### Negotiation Leverage

```
"We love your service, but we need better pricing
 or we'll route traffic to [competitor]"

"Our architecture supports multiple providers,
 we'd like to increase your share if terms improve"

"We're evaluating self-hosted options,
 what can you offer to keep our business?"
```

---

## 10. ANTI-LOCK-IN CHECKLIST

| Layer | Default | Interface | Scale-Out | Avoid |
|-------|---------|-----------|-----------|-------|
| LLM | Ollama (local) | ILLMProvider | OpenAI, Claude | Single-vendor lock-in |
| Export | Parquet | IExporter | CSV, Sheets | Proprietary formats |
| Tunnel | Tailscale | ITunnel | Cloudflare | Vendor-specific APIs |
| Compute | Polars + httpx | IComputeOrchestrator | Dask | Ray (Anyscale risk) |
| Cache | In-memory | ICache | Redis, Valkey | Managed Redis |
| Events | NATS | IEventStream | Redpanda | Kafka (complexity) |
| Language | Spanish | ILanguagePack | English, Portuguese | Hard-coded strings |
| Schema | v1.0.0 | Column Registry | Migrations | Breaking changes |

---

## SUMMARY

**Principle:** Own the contracts, swap the implementations

**Every critical layer has:**
1. Interface definition (we control)
2. Primary implementation (current vendor)
3. Alternative implementation (ready to switch)
4. Self-hosted option (emergency fallback)

**Customers depend on:**
- Our schema version (v1.x.x)
- Our language packs
- Our API contracts
- Our export formats

**Vendors become:**
- Interchangeable backends
- Competing for our routing
- Unable to lock us in
- Negotiating from weakness

---

## 11. INFRASTRUCTURE MULTIPLICATION LAYER

### Problem Statement

The current specs document **what** the system does but lack the **infrastructure multiplication layer** that enables the same code to scale from a laptop to an HPC cluster without code changes.

```
WRONG: Architecture depends on infrastructure
  laptop (4 cores) -> batch=150, workers=6 (fixed)
  cluster (400 cores) -> batch=150, workers=6 (same, wasted resources)

RIGHT: Architecture MULTIPLIES with infrastructure
  laptop (4 cores) -> auto-detect -> batch=50, workers=4, partitions=10
  cluster (400 cores) -> auto-detect -> batch=500, workers=400, partitions=1000
```

### 11.1 Portable Compute Graph Abstraction

**Missing:** No DAG/task graph that can be optimized differently per environment

```python
class IComputeGraph(Protocol):
    """Substrait-style portable compute plan"""

    def add_node(
        self,
        operation: str,
        inputs: List[str],
        outputs: List[str],
        config: Dict
    ) -> str:
        """Add operation node, return node ID"""
        ...

    def optimize(self, backend: str) -> "IComputeGraph":
        """Optimize graph for target backend"""
        ...

    def execute(self, backend: IComputeBackend) -> pa.Table:
        """Execute on any backend"""
        ...

# Same graph runs on different backends
graph = build_analysis_graph(comments)
graph.execute(LocalBackend())       # Laptop: single-threaded
graph.execute(RayBackend())         # Cluster: distributed
graph.execute(SparkBackend())       # Databricks: Spark SQL
graph.execute(DuckDBBackend())      # Edge: embedded SQL
```

### 11.2 Lazy Evaluation with Query Optimization

**Missing:** Current design is eager execution, no deferred computation

```python
# WRONG: Eager execution (current)
df = load_data()                    # Immediate load
df = normalize(df)                  # Immediate compute
df = deduplicate(df)                # Immediate compute
df = analyze(df)                    # Immediate compute

# RIGHT: Lazy evaluation with optimization
lazy_df = (
    LazyFrame.scan(path)            # Deferred
    .pipe(normalize)                # Deferred
    .pipe(deduplicate)              # Deferred
    .pipe(analyze)                  # Deferred
)
# Query optimizer fuses operations, eliminates redundant work
result = lazy_df.collect()          # Single optimized execution

# Implementation: Polars LazyFrame or Ibis expressions
```

### 11.3 Automatic Data Partitioning

**Missing:** No horizontal partitioning specification

```python
class IDataPartitioner(Protocol):
    """Auto-partition based on available resources"""

    def partition(
        self,
        data: pa.Table,
        resource_pool: ResourcePool
    ) -> List[pa.Table]:
        """Partition data based on available memory/cores"""
        ...

    def get_optimal_partition_count(
        self,
        data_size_bytes: int,
        available_memory_bytes: int,
        node_count: int
    ) -> int:
        """Calculate optimal partition count"""
        # Formula: max(1, data_size / (available_memory * 0.7 / node_count))
        ...

# Same code, different partitioning
partitioner = DataPartitioner()

# Laptop (16GB RAM, 1 node)
# 10GB dataset -> 1 partition (fits in memory)
parts = partitioner.partition(data, laptop_resources)  # [1 partition]

# Cluster (1TB RAM, 100 nodes)
# 10GB dataset -> 100 partitions (maximize parallelism)
parts = partitioner.partition(data, cluster_resources)  # [100 partitions]
```

### 11.4 Resource-Aware Scheduling

**Missing:** Fixed batch=150/workers=6 instead of dynamic resource discovery

```python
class IResourcePool(Protocol):
    """Abstract resource pool that auto-scales"""

    def discover(self) -> ResourceInventory:
        """Discover available resources"""
        ...

    def allocate(self, request: ResourceRequest) -> ResourceAllocation:
        """Allocate resources for task"""
        ...

    def release(self, allocation: ResourceAllocation) -> None:
        """Release resources"""
        ...

@dataclass
class ResourceInventory:
    cpu_cores: int
    memory_bytes: int
    gpu_count: int
    gpu_memory_bytes: int
    storage_bytes: int
    network_bandwidth_mbps: int
    node_count: int

@dataclass
class ResourceMultiplier:
    """Configuration that scales with infrastructure"""

    # Base values (laptop baseline)
    base_batch_size: int = 50
    base_workers: int = 4
    base_partitions: int = 10

    # Multipliers (auto-calculated from ResourceInventory)
    cpu_multiplier: float = 1.0      # cores / 4
    memory_multiplier: float = 1.0   # memory_gb / 16
    node_multiplier: float = 1.0     # nodes / 1

    def get_effective_batch_size(self) -> int:
        return int(self.base_batch_size * self.memory_multiplier)

    def get_effective_workers(self) -> int:
        return int(self.base_workers * self.cpu_multiplier * self.node_multiplier)

    def get_effective_partitions(self) -> int:
        return int(self.base_partitions * self.node_multiplier)

# Usage: same code, auto-scaled values
multiplier = ResourceMultiplier.from_inventory(discover_resources())
batch_size = multiplier.get_effective_batch_size()   # 50 on laptop, 500 on cluster
workers = multiplier.get_effective_workers()          # 4 on laptop, 400 on cluster
```

### 11.5 Storage Abstraction for Object Stores

**Missing:** IStorage is file-based, needs unified object store access

```python
class IObjectStore(Protocol):
    """fsspec-style unified storage abstraction"""

    def read(self, uri: str) -> pa.Table:
        """Read from any URI scheme"""
        # file:///local/path.parquet
        # s3://bucket/key.parquet
        # gs://bucket/key.parquet
        # abfss://container@account.dfs.core.windows.net/path.parquet
        ...

    def write(self, uri: str, data: pa.Table) -> None:
        """Write to any URI scheme"""
        ...

    def list(self, uri: str, pattern: str) -> List[str]:
        """List objects matching pattern"""
        ...

    def exists(self, uri: str) -> bool:
        """Check if object exists"""
        ...

# Configuration: same code, different backends
STORAGE_CONFIG = {
    "default_scheme": "file",  # Local development

    "schemes": {
        "file": {
            "backend": "local",
            "base_path": "/data",
        },
        "s3": {
            "backend": "s3",
            "endpoint": "${AWS_S3_ENDPOINT}",
            "access_key": "${AWS_ACCESS_KEY_ID}",
            "secret_key": "${AWS_SECRET_ACCESS_KEY}",
            "region": "us-east-1",
        },
        "gs": {
            "backend": "gcs",
            "credentials": "${GOOGLE_APPLICATION_CREDENTIALS}",
            "project": "${GCP_PROJECT}",
        },
        "abfss": {
            "backend": "azure",
            "account": "${AZURE_STORAGE_ACCOUNT}",
            "key": "${AZURE_STORAGE_KEY}",
        },
    }
}
```

### 11.6 Apache Flight for Zero-Copy Transport

**Missing:** Arrow IPC mentioned but not Flight RPC for distributed zero-copy

```python
class IFlightService(Protocol):
    """Arrow Flight for zero-copy distributed data"""

    def put(self, descriptor: str, data: pa.Table) -> None:
        """Send data to Flight server (zero-copy)"""
        ...

    def get(self, descriptor: str) -> pa.Table:
        """Receive data from Flight server (zero-copy)"""
        ...

    def exchange(
        self,
        descriptor: str,
        data: pa.Table
    ) -> pa.Table:
        """Bidirectional data exchange"""
        ...

# Workers communicate via Flight (no serialization)
class AnalysisWorker:
    def __init__(self, flight_client: IFlightService):
        self.flight = flight_client

    async def process_partition(self, partition_id: str) -> str:
        # Receive partition (zero-copy from coordinator)
        data = self.flight.get(f"partition/{partition_id}")

        # Process locally
        result = analyze(data)

        # Send result (zero-copy to coordinator)
        result_id = f"result/{partition_id}"
        self.flight.put(result_id, result)

        return result_id
```

### 11.7 Delta Lake/Iceberg for ACID Storage

**Missing:** No ACID storage specification for compliance/audit

```python
class ITableFormat(Protocol):
    """ACID table format abstraction"""

    def write(
        self,
        uri: str,
        data: pa.Table,
        mode: str = "append"  # append | overwrite | merge
    ) -> TableVersion:
        """Write with ACID guarantees"""
        ...

    def read(
        self,
        uri: str,
        version: Optional[int] = None,
        timestamp: Optional[datetime] = None
    ) -> pa.Table:
        """Read specific version (time-travel)"""
        ...

    def history(self, uri: str) -> List[TableVersion]:
        """Get version history (audit trail)"""
        ...

    def vacuum(self, uri: str, retention_hours: int) -> None:
        """Clean old versions"""
        ...

# Configuration
TABLE_FORMAT_CONFIG = {
    "format": "delta",  # delta | iceberg | hudi

    "delta": {
        "log_retention_days": 30,
        "checkpoint_interval": 10,
        "enable_change_data_feed": True,  # CDC for compliance
    },

    "iceberg": {
        "catalog": "rest",
        "catalog_uri": "${ICEBERG_CATALOG_URI}",
    },
}

# Usage: same code works local and cloud with full audit trail
table = DeltaTable("s3://bucket/feedback_analysis")
table.write(results, mode="append")

# Compliance: "show me data as of last Tuesday"
historical = table.read(timestamp="2025-12-10T00:00:00Z")
```

### 11.8 OpenTelemetry for Portable Observability

**Missing:** Custom logging instead of portable observability

```python
class IObservability(Protocol):
    """OpenTelemetry-style portable observability"""

    def trace(self, name: str) -> Span:
        """Create trace span"""
        ...

    def metric(
        self,
        name: str,
        value: float,
        labels: Dict[str, str]
    ) -> None:
        """Record metric"""
        ...

    def log(
        self,
        level: str,
        message: str,
        context: Dict
    ) -> None:
        """Structured log with trace context"""
        ...

# Configuration: same instrumentation, any backend
OBSERVABILITY_CONFIG = {
    "backend": "otlp",  # otlp | jaeger | zipkin | datadog | console

    "otlp": {
        "endpoint": "${OTEL_EXPORTER_OTLP_ENDPOINT}",
        "headers": {"Authorization": "Bearer ${OTEL_API_KEY}"},
    },

    "metrics": {
        "export_interval_ms": 60000,
        "resource_attributes": {
            "service.name": "feedback-analyzer",
            "service.version": "${APP_VERSION}",
        },
    },

    "traces": {
        "sampling_ratio": 0.1,  # 10% sampling in production
    },
}
```

### 11.9 Checkpointing at Partition Level

**Missing:** Only task retry, no data-level fault tolerance

```python
class ICheckpointer(Protocol):
    """Data-level fault tolerance for long-running jobs"""

    def checkpoint(
        self,
        job_id: str,
        partition_id: str,
        data: pa.Table,
        metadata: Dict
    ) -> CheckpointHandle:
        """Save partition checkpoint"""
        ...

    def restore(
        self,
        job_id: str
    ) -> Optional[JobState]:
        """Restore from last checkpoint"""
        ...

    def cleanup(self, job_id: str) -> None:
        """Remove checkpoints after success"""
        ...

@dataclass
class JobState:
    job_id: str
    total_partitions: int
    completed_partitions: List[str]
    pending_partitions: List[str]
    last_checkpoint: datetime
    partial_results: Dict[str, str]  # partition_id -> result_uri

# Usage: resume from failure without re-processing
async def process_with_checkpointing(job_id: str, data: pa.Table):
    checkpointer = get_checkpointer()

    # Try to restore from previous run
    state = checkpointer.restore(job_id)
    if state:
        logger.info(f"Resuming from checkpoint: {len(state.completed_partitions)} done")
        pending = state.pending_partitions
    else:
        pending = partition_ids(data)

    for partition_id in pending:
        result = await process_partition(partition_id)
        checkpointer.checkpoint(job_id, partition_id, result, {})

    checkpointer.cleanup(job_id)
```

### 11.10 Multi-Tenancy Resource Isolation

**Missing:** No specification for resource quotas

```python
class IResourceQuota(Protocol):
    """Multi-tenant resource isolation"""

    def get_quota(self, tenant_id: str) -> TenantQuota:
        """Get tenant's resource quota"""
        ...

    def check_quota(
        self,
        tenant_id: str,
        request: ResourceRequest
    ) -> QuotaCheckResult:
        """Check if request fits within quota"""
        ...

    def consume(
        self,
        tenant_id: str,
        usage: ResourceUsage
    ) -> None:
        """Record resource consumption"""
        ...

@dataclass
class TenantQuota:
    tenant_id: str
    max_cpu_cores: int
    max_memory_gb: int
    max_gpu_count: int
    max_storage_gb: int
    max_api_calls_per_day: int
    max_concurrent_jobs: int
    priority_class: str  # "premium" | "standard" | "economy"

# Configuration
TENANT_QUOTAS = {
    "enterprise_a": {
        "max_cpu_cores": 100,
        "max_memory_gb": 500,
        "max_concurrent_jobs": 50,
        "priority_class": "premium",
    },
    "startup_b": {
        "max_cpu_cores": 10,
        "max_memory_gb": 50,
        "max_concurrent_jobs": 5,
        "priority_class": "standard",
    },
    "default": {
        "max_cpu_cores": 4,
        "max_memory_gb": 16,
        "max_concurrent_jobs": 2,
        "priority_class": "economy",
    },
}
```

### 11.11 Resource Multiplier Configuration

**Key Concept:** Same code, infrastructure-scaled execution

```python
# CENTRAL CONFIGURATION
RESOURCE_CONFIG = {
    # Baseline (development laptop)
    "baseline": {
        "cpu_cores": 4,
        "memory_gb": 16,
        "nodes": 1,
        "batch_size": 50,
        "workers": 4,
        "partitions": 10,
    },

    # Auto-discovery (default: detect from environment)
    "discovery": "auto",  # auto | manual | kubernetes | ray

    # Multiplier formulas
    "formulas": {
        "batch_size": "baseline * (memory_gb / baseline_memory_gb)",
        "workers": "baseline * (cpu_cores / baseline_cpu_cores) * nodes",
        "partitions": "baseline * nodes",
    },

    # Caps (safety limits)
    "caps": {
        "max_batch_size": 1000,
        "max_workers": 1000,
        "max_partitions": 10000,
    },
}

# Result: same code scales automatically
#
# Laptop (4 cores, 16GB, 1 node):
#   batch_size = 50, workers = 4, partitions = 10
#
# Workstation (32 cores, 128GB, 1 node):
#   batch_size = 400, workers = 32, partitions = 10
#
# Small cluster (100 cores, 500GB, 10 nodes):
#   batch_size = 400, workers = 100, partitions = 100
#
# Enterprise cluster (1000 cores, 5TB, 100 nodes):
#   batch_size = 1000 (capped), workers = 1000 (capped), partitions = 1000
#
# Databricks/AWS (10000 cores, 50TB, 1000 nodes):
#   batch_size = 1000 (capped), workers = 1000 (capped), partitions = 10000 (capped)
```

---

## 12. TECHNOLOGY CHOICES FOR MULTIPLICATION

### Recommended Stack for Infrastructure Multiplication

| Layer | Choice | Rationale |
|-------|--------|-----------|
| DataFrame | Polars | Lazy evaluation, query optimization, 10x faster than pandas |
| Compute Graph | Substrait | Portable plans across DuckDB/Spark/DataFusion |
| Parallelism | Polars/Rayon | Rust-native, no orchestrator overhead |
| Scale-Out | Dask | Python-native, DataFrame-focused (if needed) |
| Transport | Arrow Flight | Zero-copy RPC, no serialization |
| Storage | Delta Lake + fsspec | ACID + any cloud, time-travel for compliance |
| Observability | OpenTelemetry | Any backend, correlation across services |
| Checkpointing | Delta Lake transactions | Built-in, no extra infrastructure |

> **Note:** Ray Data is NOT recommended. For typical workloads (50-150MB), Polars processes in <2 seconds. See `BLINDSPOTS.md` for rationale.

### Migration Path (Invariant Steps)

Steps ordered by dependency - each unlocks the next capability.

```
Step A: Polars + fsspec (FOUNDATION)
  Unlocks: Lazy evaluation, cloud storage
  Depends on: Nothing (can start immediately)
  - Replace pandas with Polars LazyFrame
  - Replace file paths with fsspec URIs
  - Same code works local and S3
  Invariant: All subsequent steps assume Polars LazyFrame

Step B: Dask (OPTIONAL DISTRIBUTION)
  Unlocks: Auto-partitioning, cluster scaling
  Depends on: Step A (Polars provides the LazyFrame to wrap)
  - Wrap Polars in Dask DataFrames (if scale-out needed)
  - Auto-partitioning kicks in
  - Same code scales to cluster
  Invariant: Only needed if single-machine is insufficient
  Note: Ray is NOT recommended (Anyscale vendor risk) - use Dask first

Step C: Delta Lake (ACID + COMPLIANCE)
  Unlocks: Time-travel, audit trail, CDC
  Depends on: Step A (fsspec URIs for storage)
  - Replace Parquet writes with Delta
  - Get time-travel, audit, CDC for free
  - Same code works local and cloud
  Invariant: Can run parallel to Step B (independent)

Step D: Flight RPC (ZERO-COPY)
  Unlocks: No serialization overhead, max throughput
  Depends on: Step B (distributed workers need Flight)
  - Replace Redis/HTTP with Flight
  - Workers communicate without serialization
  - Massive throughput improvement
  Invariant: Only beneficial after distribution exists
```

**Dependency Graph:**

```
Step A (Polars + fsspec) [REQUIRED]
    |
    +---> Step B (Dask) ---> Step D (Flight RPC) [OPTIONAL - only if scale-out needed]
    |
    +---> Step C (Delta Lake) [RECOMMENDED - ACID compliance]
```

---

## 13. INFRASTRUCTURE MULTIPLICATION CHECKLIST

| Capability | Interface | Laptop | Workstation | Cluster | HPC |
|------------|-----------|--------|-------------|---------|-----|
| Compute Graph | IComputeGraph | DuckDB | DuckDB | Dask/Spark | Spark |
| Lazy Evaluation | Polars LazyFrame | Yes | Yes | Yes | Yes |
| Partitioning | IDataPartitioner | 1 part | 10 parts | 100 parts | 10K parts |
| Resource Discovery | IResourcePool | 4 cores | 32 cores | 1K cores | 10K cores |
| Object Storage | IObjectStore | file:// | file:// | s3:// | s3:// |
| Zero-Copy Transport | IFlightService | In-process | In-process | Flight RPC | Flight RPC |
| ACID Storage | ITableFormat | Delta local | Delta local | Delta S3 | Delta S3 |
| Observability | IObservability | Console | Console | OTLP | OTLP |
| Checkpointing | ICheckpointer | Local disk | Local disk | S3 | S3 |
| Multi-Tenancy | IResourceQuota | Single | Single | Yes | Yes |

> **Note:** Ray is intentionally excluded. Use Dask for cluster scale-out. See `BLINDSPOTS.md` and `STRATEGY.md` for rationale.

---

**Generated:** 2025-12-13
**Strategy:** Judo - use vendor momentum against them
**Goal:** Become the indispensable integration point
**Extended:** Infrastructure multiplication layer for laptop-to-HPC scalability

---

## APPENDIX A: LLM PROVIDER CONTRACT IMPLEMENTATION (2025-12-15)

### A.1 Authoritative Interface Reference

Section 1 (LLM Provider Abstraction) is now implemented in detail in:

```
📄 LLM_PROVIDER_CONTRACT.md (Authoritative Source)
```

This appendix summarizes key implementation decisions and how they realize the goals in Section 1.

### A.2 Section 1 Goals → Implementation Mapping

| Section 1 Goal | LLM_PROVIDER_CONTRACT.md Implementation |
|----------------|----------------------------------------|
| "No fallback" → Resilient | `LLMRouter` with 5 routing strategies |
| "No local option" → Local-first | Ollama as priority 1, cloud as fallback |
| "Price changes = cost explosion" | `ProviderCapabilities.cost_per_1k_*` + cost routing |
| "Rate limit changes = degradation" | Health checks + automatic failover |

### A.3 Interface Contract Realization

**Section 1 proposed:**
```python
class ILLMProvider(Protocol):
    async def analyze_batch(self, comments, language, schema) -> List[AnalysisResult]
    def estimate_cost(self, comments) -> CostEstimate
    def get_capabilities(self) -> ProviderCapabilities
    @property
    def provider_id(self) -> str
```

**LLM_PROVIDER_CONTRACT.md implements:**
```python
class ILLMProvider(Protocol):
    def get_capabilities(self) -> ProviderCapabilities  # Includes cost info
    async def analyze_batch(self, request: AnalysisRequest) -> List[AnalysisResult]
    async def health_check(self) -> bool  # NEW: Required for routing

@dataclass
class AnalysisRequest:
    comments: pa.Array          # Arrow-native (zero-copy)
    language: str
    analysis_schema: Dict
```

**Key Changes:**
- `estimate_cost()` removed → Cost info in `ProviderCapabilities` (no separate call)
- `provider_id` moved into `ProviderCapabilities` dataclass
- `health_check()` added → Required for routing decisions
- Input changed to `pa.Array` → Arrow-native, zero-copy from source table

### A.4 Adapter Swappability Verification

Section 1 required: "Switching vendors SHALL require configuration changes, NOT code changes."

**Verification Test (from LLM_PROVIDER_CONTRACT.md Section 5.3):**
```python
async def test_adapter_contract(adapter: ILLMProvider):
    """Every adapter must pass this test"""

    # 1. Capabilities are valid
    caps = adapter.get_capabilities()
    assert caps.provider_id is not None

    # 2. Health check works
    is_healthy = await adapter.health_check()
    assert isinstance(is_healthy, bool)

    # 3. Can analyze a batch
    request = AnalysisRequest(
        comments=pa.array(["Test"]),
        language="en",
        analysis_schema=MINIMAL_SCHEMA
    )
    results = await adapter.analyze_batch(request)
    assert len(results) == 1
```

**Configuration-Only Switching:**
```python
# Switch from Ollama to OpenAI: change config, not code
LLM_CONFIG = {
    "routing": {"strategy": "local_first"},
    "providers": {
        "ollama": {"enabled": True, "priority": 1},   # ← Disable this
        "openai": {"enabled": True, "priority": 10},  # ← Enable this
    }
}
# No code changes required. Router automatically uses OpenAI.
```

### A.5 OpenAI-Compatible Base Pattern

Section 1 listed providers individually. LLM_PROVIDER_CONTRACT.md introduces a base class pattern:

```
90% of providers share OpenAI API format:
├── Ollama, vLLM, llama.cpp, LM Studio (local)
├── OpenAI, Azure OpenAI (cloud)
└── Groq, Together, Mistral, DeepSeek (cloud)

→ OpenAICompatibleBase (~50 lines) handles all of these
→ Only override: endpoint, auth, model name

10% need custom adapters:
├── AnthropicAdapter (~100 lines) - different message format
└── GeminiAdapter (~100 lines) - different API structure
```

**Implication:** Adding new OpenAI-compatible provider = ~10 lines of config.

### A.6 Section 10 Anti-Lock-In Checklist Update

| Layer | Section 10 Status | LLM_PROVIDER_CONTRACT.md Status |
|-------|-------------------|--------------------------------|
| LLM Interface | ✓ Defined | ✓ Implemented with Arrow-native input |
| OpenAI Adapter | ✓ Defined | ✓ Implemented (extends base) |
| Anthropic Adapter | ✓ Defined | ✓ Implemented (custom format) |
| Local Adapter | ✓ Defined (Ollama) | ✓ Implemented (Ollama, vLLM, llama.cpp) |
| Router | ✓ Defined | ✓ Implemented with 5 strategies |
| Health Check | ✗ Not defined | ✓ Added to interface |
| Batch Orchestrator | ✗ Not defined | ✓ Arrow-native implementation |

### A.7 Performance Guarantees

Section 1 mentioned performance but didn't specify. LLM_PROVIDER_CONTRACT.md adds:

**Zero-Copy Boundaries:**
```
✓ Table column extraction: table.column("comment") → pa.Array
✓ Result column append: table.append_column("sentiment", array)
✓ Array slicing for batches: comments[start:end]

✗ Unavoidable copies (at API boundary only):
  - Arrow Array → Python list for API call
  - API response → Python dict
  - Python list → Arrow Array for results
```

**Batch Size Guidelines:**
```python
BATCH_SIZE = {
    "ollama_7b": 10,   # ~2GB VRAM per batch
    "ollama_70b": 2,   # ~20GB VRAM per batch
    "vllm": 50,        # Continuous batching
    "openai": 50,      # Rate-limit bound
}
```

### A.8 Local-First Default Strategy

Section 1 listed OpenAI as primary. LLM_PROVIDER_CONTRACT.md inverts this:

**Original (Section 1):**
```python
fallback_chain = ["openai", "anthropic", "google", "local"]
```

**Updated (LLM_PROVIDER_CONTRACT.md):**
```python
fallback_chain = ["ollama", "vllm", "openai", "anthropic"]

# Default routing strategy
routing = {
    "strategy": "local_first",
    "local_providers": ["ollama", "vllm", "llamacpp"],
    "cloud_providers": ["openai", "anthropic"],
}
```

**Rationale:**
- Local = zero cost, zero latency to API, works offline
- Cloud = fallback for edge cases, premium features
- 95% of requests handled locally → 95% cost reduction

### A.9 Cross-Reference Table

| This Document Section | LLM_PROVIDER_CONTRACT.md Section |
|-----------------------|---------------------------------|
| 1. LLM Provider Abstraction | 1. Core Interface |
| 1. Provider Capabilities | 1.1 ProviderCapabilities dataclass |
| 1. Router Strategy | 3. Provider Router |
| 1. Configuration | 4. Configuration |
| 10. Anti-Lock-In Checklist | 5. Adapter Swappability Guarantees |

---

## APPENDIX B: DOCUMENT CROSS-REFERENCES (2025-12-15)

### B.1 Blueprint Document Hierarchy

```
📁 blueprint/
├── BLUEPRINT.md                    # Product requirements (WHAT)
│   └── Appendix E: LLM Contract Update
│
├── AGNOSTIC_BLUEPRINT.md           # Stack-agnostic spec (HOW, abstractly)
│   └── Appendix D: LLM Contract Alignment
│
├── TECHNICAL_SPEC_STACK_AGNOSTIC.md # Detailed technical spec (HOW, concretely)
│   └── Appendix D: Local-First LLM Architecture
│
├── TRUE_AGNOSTIC_BACKEND.md        # Anti-lock-in strategy (WHY)
│   └── Appendix A: LLM Contract Implementation (this)
│
└── LLM_PROVIDER_CONTRACT.md        # LLM interface specification (AUTHORITATIVE)
    ├── 1. Core Interface
    ├── 2. Adapter Implementations
    ├── 3. Provider Router
    ├── 4. Configuration
    ├── 5. Swappability Guarantees
    ├── 6. Performance Considerations
    └── 7. Future Extensions
```

### B.2 Reading Order for New Developers

1. **BLUEPRINT.md** - Understand what the system does
2. **LLM_PROVIDER_CONTRACT.md** - Understand LLM interface (start here for LLM work)
3. **AGNOSTIC_BLUEPRINT.md** - Understand all interfaces
4. **TRUE_AGNOSTIC_BACKEND.md** - Understand anti-lock-in strategy
5. **TECHNICAL_SPEC_STACK_AGNOSTIC.md** - Implementation details

### B.3 Authoritative Sources by Topic

| Topic | Authoritative Document |
|-------|----------------------|
| LLM Interface | `LLM_PROVIDER_CONTRACT.md` |
| Output Schema (36 columns) | `BLUEPRINT.md` Section 3 |
| Domain Algorithms | `BLUEPRINT.md` Section 4 |
| Delegation Contracts | `AGNOSTIC_BLUEPRINT.md` Section 4 |
| Cache Strategy | `TECHNICAL_SPEC_STACK_AGNOSTIC.md` Section 3 |
| Anti-Lock-In Strategy | `TRUE_AGNOSTIC_BACKEND.md` |
