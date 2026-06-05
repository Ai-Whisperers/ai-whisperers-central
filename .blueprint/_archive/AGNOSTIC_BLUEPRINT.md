# Customer Feedback Analyzer - Agnostic Blueprint

**Document Type:** Product Requirements Specification
**Version:** 1.2.0
**Date:** 2025-12-14
**Purpose:** Implementation blueprint for a vendor-agnostic customer feedback analysis system

---

## TABLE OF CONTENTS

1. [System Overview](#1-system-overview)
2. [Core Architecture Principle](#2-core-architecture-principle)
3. [Unconditional Core: Apache Arrow](#3-unconditional-core-apache-arrow)
4. [Delegation Contracts](#4-delegation-contracts)
5. [Input Specifications](#5-input-specifications)
6. [Output Specifications](#6-output-specifications)
7. [Domain Algorithms](#7-domain-algorithms)
8. [AI Integration](#8-ai-integration)
9. [Caching Strategy](#9-caching-strategy)
10. [Container Architecture](#10-container-architecture)
11. [Observability](#11-observability)
12. [Validation Criteria](#12-validation-criteria)
13. [Non-Functional Requirements](#13-non-functional-requirements)
14. [Configuration Reference](#14-configuration-reference)
15. [Domain Data Assets](#15-domain-data-assets)

---

## 1. SYSTEM OVERVIEW

### 1.1 Purpose

The system SHALL analyze customer feedback text to extract actionable business intelligence including sentiment, emotions, churn risk, and pain points.

### 1.2 Functional Scope

The system SHALL provide:

1. **Sentiment Analysis** - Score 0-10 with category classification
2. **Emotion Detection** - 7 emotion categories with intensity scores
3. **Churn Risk Calculation** - 0-100 score with actionable recommendations
4. **Pain Point Classification** - 21 category taxonomy with keyword extraction
5. **NPS Categorization** - Promoter/Passive/Detractor from ratings
6. **Duplicate Detection** - Exact and near-duplicate grouping
7. **Priority Scoring** - 0-100 review priority for triage
8. **Structured Export** - Tabular output with 36 analysis columns

### 1.3 Language Support

The system SHALL support Spanish (es) as the primary language with extensible language pack architecture for future languages.

---

## 2. CORE ARCHITECTURE PRINCIPLE

### 2.1 Guiding Philosophy

```
PRINCIPLE: Own the contracts, swap the implementations.

The system architecture SHALL be defined by INTERFACES, not IMPLEMENTATIONS.
Every infrastructure choice SHALL flow through a delegation contract.
Switching vendors SHALL require configuration changes, NOT code changes.
```

### 2.2 Dependency Classification

| Classification | Meaning | Example |
|----------------|---------|---------|
| UNCONDITIONAL | Hardcoded, non-negotiable | Apache Arrow |
| RECOMMENDED | Default stack, swappable | DataFusion (engine), Parquet (storage), DuckDB (query) |
| DELEGATED | Behind interface, swappable | Compute, Tunnel, Cache, Observability |
| OPTIONAL | Feature flag controlled | Specific export formats, scale-out orchestrators |

### 2.3 Recommended Stack (Government-Grade)

```
PRODUCTION STACK (Apache Foundation governed, zero vendor lock-in):

Arrow (FORMAT - Unconditional)
  |-- Memory layout contract
  |-- Zero-copy data sharing
  |-- All data flows as pa.Table
  |
DataFusion (PIPELINE ENGINE - Recommended)
  |-- Apache-governed Rust query engine
  |-- Algebraic optimization (predicate pushdown, projection)
  |-- Substrait export for portability
  |-- Embeddable, no server required
  |
Parquet (COLD STORAGE - Recommended)
  |-- Arrow's native file format
  |-- Columnar, compressed, universally readable
  |-- Zero deserialization overhead with Arrow
  |
DuckDB (QUERY INTERFACE - Recommended for Debug/Observability)
  |-- MIT license, DuckDB Foundation
  |-- Zero-copy Arrow interchange
  |-- SQL interface for analysts/debugging
  |-- Embedded, single-file database
  |
Polars (DATAFRAME OPS - Optional)
  |-- Built on arrow-rs (Rust Arrow)
  |-- LazyFrame with query optimization
  |-- Alternative to DataFusion for DataFrame-first workflows

WHY THIS STACK:
- All Apache/MIT governed (FedRAMP-adjacent procurement friendly)
- Zero vendor lock-in (no VC-backed open-core)
- Used by US federal agencies, defense contractors, big tech
- Full audit trail, security-audited, long-term stability
```

### 2.4 Lock-In Prevention Strategy

```
EVERY external dependency (except Arrow) SHALL:
  1. Be accessed through an interface (Protocol)
  2. Have at least one alternative implementation defined
  3. Have a self-hosted/local fallback option
  4. Be configurable via environment variables
```

---

## 3. UNCONDITIONAL CORE: APACHE ARROW

### 3.1 Rationale

Apache Arrow is the ONLY unconditional dependency because:

- Apache Foundation governance (no commercial entity steering adoption)
- Language-agnostic columnar format (C++, Python, Rust, Go, Java, JS)
- Zero-copy data sharing (eliminates serialization overhead)
- Industry standard (Pandas 2.0, Polars, DuckDB, Spark all use Arrow)
- Open specification (anyone can implement)

### 3.2 Arrow Usage Requirements

The system SHALL use Arrow for:

```python
# 3.2.1 Internal Data Representation
# ALL internal data processing SHALL use PyArrow Tables
internal_data: pa.Table  # NOT pandas.DataFrame

# 3.2.2 Inter-Process Communication
# ALL data transfer between services SHALL use Arrow IPC
arrow_ipc_stream: pa.ipc.RecordBatchStreamWriter

# 3.2.3 Persistent Storage
# Cold storage SHALL use Parquet format (Arrow's file format)
storage_format: "parquet"  # Columnar, compressed, universally readable

# 3.2.4 Network Streaming
# High-throughput data transfer SHALL use Arrow Flight
flight_client: pa.flight.FlightClient
```

### 3.3 Arrow Schema Definition

```python
FEEDBACK_SCHEMA = pa.schema([
    # Input columns
    pa.field("row_id", pa.int64(), nullable=False),
    pa.field("user_score", pa.float64(), nullable=True),
    pa.field("customer_comment", pa.utf8(), nullable=False),

    # Analysis columns (36 total - see Section 6)
    pa.field("ai_sentiment", pa.float64()),
    pa.field("analysis_score", pa.float64()),
    pa.field("score_source", pa.utf8()),
    pa.field("sentiment_category", pa.utf8()),
    pa.field("emotion", pa.utf8()),
    pa.field("churn_risk", pa.int32()),
    pa.field("review_priority_score", pa.int32()),
    pa.field("pain_point_primary", pa.utf8()),
    # ... (complete schema in Section 6)
])
```

### 3.4 Medallion Architecture

The system SHALL implement a medallion data architecture:

```
BRONZE (Raw)
  |-- Ingested data as-is
  |-- Parquet format
  |-- Schema: source columns + metadata
  |
  v
SILVER (Validated)
  |-- Normalized, deduplicated
  |-- Schema enforced
  |-- Quality flags applied
  |
  v
GOLD (Enriched)
  |-- All 36 analysis columns populated
  |-- Ready for export
  |-- Business-ready format
```

---

## 4. DELEGATION CONTRACTS

### 4.1 IComputeOrchestrator

**Purpose:** Abstract distributed/parallel computation

```python
from typing import Protocol, List, Any, Callable, TypeVar
from concurrent.futures import Future

T = TypeVar('T')
R = TypeVar('R')

class IComputeOrchestrator(Protocol):
    """
    Vendor-agnostic compute orchestration.

    Implementations: Ray, Dask, asyncio, Celery, Spark
    """

    async def map_batch(
        self,
        func: Callable[[T], R],
        items: List[T],
        batch_size: int = 100
    ) -> List[R]:
        """Apply function to items in parallel batches."""
        ...

    async def submit(
        self,
        func: Callable[..., R],
        *args: Any,
        **kwargs: Any
    ) -> Future[R]:
        """Submit single task for async execution."""
        ...

    def get_resource_inventory(self) -> "ResourceInventory":
        """Discover available compute resources."""
        ...

    def scale(self, workers: int) -> None:
        """Scale worker pool up or down."""
        ...

    @property
    def orchestrator_id(self) -> str:
        """Unique identifier for logging/routing."""
        ...


@dataclass
class ResourceInventory:
    cpu_cores: int
    memory_bytes: int
    gpu_count: int
    gpu_memory_bytes: int
    node_count: int

    def get_optimal_batch_size(self, base: int = 50) -> int:
        """Calculate batch size based on available memory."""
        memory_gb = self.memory_bytes / (1024**3)
        multiplier = memory_gb / 16  # 16GB baseline
        return int(base * max(1.0, multiplier))

    def get_optimal_workers(self, base: int = 4) -> int:
        """Calculate worker count based on CPU cores."""
        return int(base * (self.cpu_cores / 4) * self.node_count)
```

**Portable Parallelism Strategy:**

```
PRINCIPLE: Let Rust handle parallelism, Python handles orchestration.

Python's multiprocessing has real portability issues:
  - ProcessPoolExecutor: Pickling hell, fork vs spawn, memory copying
  - asyncio: Event loop nesting, Windows limitations, sync/async mixing
  - Threading: GIL blocks CPU parallelism

SOLUTION: Delegate parallelism to Rust-based tools that handle it internally.
```

**Implementation Hierarchy (Prefer Top to Bottom):**

```
TIER 1: DEFAULT (Rust Parallelism - Zero Python Threading Hell)
  Polars LazyFrame + httpx/anyio
    - Polars uses Rayon (Rust thread pool) internally
    - No GIL, no pickling, no fork/spawn issues
    - httpx + anyio for async I/O (backend-agnostic)
    - Python stays synchronous for orchestration

TIER 2: PIPELINE ENGINE (Query Optimization)
  DataFusion
    - Uses Tokio (Rust async runtime) internally
    - Algebraic optimization built-in
    - Substrait export for portability
    - Python wrapper is thin, Rust does the work

TIER 3: HYBRID (When You Need Python UDFs)
  Polars + map_elements with native Python
    - Polars parallelizes across partitions
    - Each partition runs Python UDF
    - Still better than ProcessPoolExecutor (Polars manages it)

TIER 4: SCALE-OUT (If You Outgrow Single Machine)
  Dask (community-governed)
    - Only when data exceeds single machine RAM
    - delayed() pattern, easy to remove
    - No vendor lock-in

TIER 5: AVOID UNLESS FORCED
  Ray / ProcessPoolExecutor / manual asyncio
    - ProcessPoolExecutor: Pickling issues, platform-specific
    - asyncio mixing: Event loop hell
    - Ray: Vendor risk + complexity
```

**Portable Parallelism Patterns:**

```python
# WRONG: Python multiprocessing hell
from concurrent.futures import ProcessPoolExecutor
with ProcessPoolExecutor() as pool:
    results = pool.map(transform, chunks)  # Pickling, fork/spawn, memory copy

# WRONG: asyncio contamination
async def process_all():
    tasks = [async_transform(row) for row in data]
    return await asyncio.gather(*tasks)  # Event loop hell, exception swallowing

# RIGHT: Let Polars handle parallelism (Rayon internally)
result = (
    df.lazy()
    .with_columns([
        pl.col("comment").map_elements(sentiment_fn, return_dtype=pl.Float64)
    ])
    .collect()  # Rust parallelism, no GIL, no pickle
)

# RIGHT: Isolated async only for I/O (LLM calls)
import httpx
import anyio  # Backend-agnostic (works with asyncio or trio)

async def call_llm_batch(comments: list[str]) -> list[dict]:
    async with httpx.AsyncClient() as client:
        responses = []
        for batch in chunk(comments, 50):
            resp = await client.post(LLM_ENDPOINT, json={"comments": batch})
            responses.extend(resp.json()["results"])
        return responses

# Run async in isolation, don't let it contaminate sync code
results = anyio.run(call_llm_batch, comments)
```

**Swappable Implementations:**

| Implementation | Use Case | Self-Hosted | Vendor Risk | Parallelism |
|----------------|----------|-------------|-------------|-------------|
| PolarsOrchestrator | Default, single-machine | Yes | Low (Apache 2.0) | Rayon (Rust) |
| DataFusionOrchestrator | Query optimization | Yes | None (Apache) | Tokio (Rust) |
| DaskOrchestrator | Scale-out only | Yes | Low (community) | Distributed |
| RayOrchestrator | Customer demands only | Yes | HIGH (Anyscale) | Ray runtime |

**I/O Async Stack (Isolated):**

| Component | Library | Why |
|-----------|---------|-----|
| HTTP client | httpx | Sync and async API, modern |
| Async runtime | anyio | Backend-agnostic (asyncio/trio) |
| LLM calls | httpx.AsyncClient | Only async needed here |
| File I/O | Sync (Polars handles) | No async file I/O needed |

---

### 4.2 ITunnel

**Purpose:** Abstract secure ingress/edge connectivity

```python
class ITunnel(Protocol):
    """
    Vendor-agnostic tunnel/edge abstraction.

    Implementations: Cloudflare, Tailscale, WireGuard, Caddy, Nginx, Ngrok
    """

    async def connect(self) -> "TunnelConnection":
        """Establish tunnel connection."""
        ...

    async def disconnect(self) -> None:
        """Close tunnel connection."""
        ...

    def get_public_url(self) -> str:
        """Get public-facing URL."""
        ...

    def get_health(self) -> "TunnelHealth":
        """Get connection health status."""
        ...

    def get_capabilities(self) -> "TunnelCapabilities":
        """Query what this tunnel provides."""
        ...

    @property
    def tunnel_id(self) -> str:
        """Unique identifier."""
        ...


@dataclass
class TunnelCapabilities:
    provides_ddos_protection: bool
    provides_waf: bool
    provides_auth: bool
    provides_rate_limiting: bool
    provides_tls_termination: bool
    supports_websocket: bool
    supports_grpc: bool
    self_hostable: bool


@dataclass
class TunnelHealth:
    connected: bool
    latency_ms: int
    uptime_seconds: int
    errors_last_hour: int
```

**Swappable Implementations:**

| Implementation | Capabilities | Self-Hosted |
|----------------|--------------|-------------|
| CloudflareTunnel | DDoS, WAF, Auth, Rate Limiting | No (managed) |
| TailscaleTunnel | Mesh VPN, ACL | Yes |
| WireGuardTunnel | VPN only | Yes |
| CaddyTunnel | TLS, Reverse Proxy | Yes |
| NginxTunnel | Reverse Proxy | Yes |
| NgrokTunnel | Quick setup, dev | No (managed) |

**Edge Requirements Contract:**

```python
# If tunnel doesn't provide these, system SHALL implement internally
EDGE_REQUIREMENTS = {
    "rate_limiting": "REQUIRED",    # Tunnel OR internal middleware
    "authentication": "REQUIRED",   # Tunnel OR internal middleware
    "tls_termination": "REQUIRED",  # Tunnel OR internal
    "ddos_protection": "RECOMMENDED",
    "waf": "RECOMMENDED",
}
```

---

### 4.3 ICache

**Purpose:** Abstract key-value caching

```python
from typing import Optional, Dict, List, Any

class ICache(Protocol):
    """
    Vendor-agnostic caching abstraction.

    Implementations: Redis, Valkey, DragonflyDB, KeyDB, Memcached, Local
    """

    async def get(self, key: str) -> Optional[Any]:
        """Get value by key."""
        ...

    async def set(
        self,
        key: str,
        value: Any,
        ttl_seconds: Optional[int] = None
    ) -> bool:
        """Set value with optional TTL."""
        ...

    async def get_many(self, keys: List[str]) -> Dict[str, Any]:
        """Batch get multiple keys."""
        ...

    async def set_many(
        self,
        entries: Dict[str, Any],
        ttl_seconds: Optional[int] = None
    ) -> int:
        """Batch set multiple entries. Returns count of successful sets."""
        ...

    async def delete(self, key: str) -> bool:
        """Delete key."""
        ...

    async def exists(self, key: str) -> bool:
        """Check if key exists."""
        ...

    async def get_stats(self) -> "CacheStats":
        """Get cache statistics."""
        ...

    @property
    def cache_id(self) -> str:
        """Unique identifier."""
        ...


@dataclass
class CacheStats:
    hits: int
    misses: int
    hit_rate: float
    memory_used_bytes: int
    keys_count: int
```

**Swappable Implementations:**

| Implementation | Protocol | Self-Hosted |
|----------------|----------|-------------|
| RedisCache | RESP | Yes |
| ValkeyCache | RESP (Redis fork) | Yes |
| DragonflyCache | RESP (Redis-compatible) | Yes |
| KeyDBCache | RESP (Redis fork) | Yes |
| MemcachedCache | Memcached | Yes |
| LocalCache | In-memory dict | Yes |

---

### 4.4 IObservability

**Purpose:** Abstract metrics, traces, and logs

```python
from typing import Dict, Optional, ContextManager

class IObservability(Protocol):
    """
    Vendor-agnostic observability abstraction.

    Implementations: OpenTelemetry, Prometheus+Jaeger, Datadog, Redpanda+Grafana
    """

    def trace(self, name: str, attributes: Optional[Dict] = None) -> ContextManager:
        """Create trace span context manager."""
        ...

    def metric(
        self,
        name: str,
        value: float,
        labels: Optional[Dict[str, str]] = None,
        metric_type: str = "gauge"  # gauge | counter | histogram
    ) -> None:
        """Record metric value."""
        ...

    def log(
        self,
        level: str,  # debug | info | warning | error | critical
        message: str,
        context: Optional[Dict] = None
    ) -> None:
        """Structured log with trace context."""
        ...

    def event(
        self,
        event_type: str,
        payload: Dict,
        topic: Optional[str] = None
    ) -> None:
        """Emit event for streaming/alerting."""
        ...

    @property
    def observability_id(self) -> str:
        """Unique identifier."""
        ...
```

**Swappable Implementations:**

| Implementation | Components | Self-Hosted |
|----------------|------------|-------------|
| OpenTelemetryObservability | OTLP to any backend | Yes |
| PrometheusJaegerObservability | Prometheus + Jaeger | Yes |
| RedpandaGrafanaObservability | Redpanda + Grafana | Yes |
| DatadogObservability | Datadog Agent | No (managed) |
| ConsoleObservability | stdout/stderr | Yes |

---

### 4.5 IEventStream

**Purpose:** Abstract event streaming/messaging

```python
from typing import Callable, Awaitable, Optional

class IEventStream(Protocol):
    """
    Vendor-agnostic event streaming abstraction.

    Implementations: Redpanda, Kafka, NATS, RabbitMQ, Redis Streams
    """

    async def publish(
        self,
        topic: str,
        event: Dict,
        key: Optional[str] = None
    ) -> None:
        """Publish event to topic."""
        ...

    async def subscribe(
        self,
        topic: str,
        handler: Callable[[Dict], Awaitable[None]],
        group_id: Optional[str] = None
    ) -> "Subscription":
        """Subscribe to topic with handler."""
        ...

    async def create_topic(
        self,
        topic: str,
        partitions: int = 1,
        retention_hours: int = 168  # 7 days
    ) -> None:
        """Create topic if not exists."""
        ...

    @property
    def stream_id(self) -> str:
        """Unique identifier."""
        ...
```

**Swappable Implementations:**

| Implementation | Protocol | Self-Hosted |
|----------------|----------|-------------|
| RedpandaStream | Kafka-compatible | Yes |
| KafkaStream | Kafka | Yes |
| NATSStream | NATS | Yes |
| RabbitMQStream | AMQP | Yes |
| RedisStream | Redis Streams | Yes |

---

### 4.6 ILLMProvider

**Purpose:** Abstract LLM API access

```python
from typing import List, Optional
from dataclasses import dataclass

@dataclass
class AnalysisResult:
    emotions: Dict[str, float]
    sentiment_score: float
    pain_points: List[str]
    keywords: List[str]
    confidence: float
    raw_response: Optional[Dict] = None

@dataclass
class CostEstimate:
    input_tokens: int
    output_tokens: int
    estimated_cost_usd: float
    provider: str

@dataclass
class ProviderCapabilities:
    supports_structured_output: bool
    supports_batch: bool
    supports_streaming: bool
    max_context_tokens: int
    max_output_tokens: int
    languages: List[str]
    cost_per_1k_input: float
    cost_per_1k_output: float


class ILLMProvider(Protocol):
    """
    Vendor-agnostic LLM abstraction.

    Implementations: OpenAI, Anthropic, Google, Ollama, vLLM
    """

    async def analyze_batch(
        self,
        comments: List[str],
        language: str,
        schema: Dict  # JSON schema for structured output
    ) -> List[AnalysisResult]:
        """Batch analysis with structured output."""
        ...

    async def analyze_single(
        self,
        comment: str,
        language: str,
        schema: Dict
    ) -> AnalysisResult:
        """Single comment analysis."""
        ...

    def estimate_cost(self, comments: List[str]) -> CostEstimate:
        """Pre-flight cost estimation."""
        ...

    def get_capabilities(self) -> ProviderCapabilities:
        """Query provider capabilities."""
        ...

    @property
    def provider_id(self) -> str:
        """Unique identifier for routing/logging."""
        ...
```

**Swappable Implementations:**

| Implementation | Models | Self-Hosted |
|----------------|--------|-------------|
| OpenAIProvider | GPT-4o, GPT-4o-mini | No |
| AnthropicProvider | Claude 3.5, Claude 3 | No |
| GoogleProvider | Gemini 1.5 | No |
| OllamaProvider | Llama 3, Mistral, etc. | Yes |
| vLLMProvider | Any HuggingFace model | Yes |

**Routing Strategy:**

```python
class LLMRouter:
    """Intelligent provider routing."""

    strategies = {
        "cost_optimized": route_by_lowest_cost,
        "latency_optimized": route_by_lowest_latency,
        "quality_optimized": route_by_highest_quality,
        "balanced": route_by_weighted_score,
        "failover": route_with_fallback_chain,
    }

    def fallback_chain(self) -> List[str]:
        return [
            "openai",      # Primary (best structured output)
            "anthropic",   # Secondary (best reasoning)
            "google",      # Tertiary (best multilingual)
            "ollama",      # Emergency (no cost, slower)
        ]
```

---

### 4.7 IExporter

**Purpose:** Abstract export format generation

```python
class IExporter(Protocol):
    """
    Vendor-agnostic export abstraction.

    Implementations: Parquet, CSV, GoogleSheets, Excel, JSON
    """

    def export(
        self,
        data: pa.Table,  # Arrow Table as canonical format
        destination: str,  # Path or URL
        options: Optional[Dict] = None
    ) -> "ExportResult":
        """Export data to target format/destination."""
        ...

    def get_supported_formats(self) -> List[str]:
        """List supported output formats."""
        ...

    @property
    def exporter_id(self) -> str:
        """Unique identifier."""
        ...


@dataclass
class ExportResult:
    success: bool
    destination: str
    rows_exported: int
    bytes_written: int
    format: str
    metadata: Optional[Dict] = None
```

**Export Format Priority:**

```python
EXPORT_FORMATS = {
    # PRIMARY - Always available (Arrow-native)
    "parquet": {"priority": 1, "always_available": True},
    "arrow_ipc": {"priority": 2, "always_available": True},
    "csv": {"priority": 3, "always_available": True},

    # SECONDARY - Convenience wrappers (require credentials)
    "google_sheets": {"priority": 10, "requires": ["GOOGLE_OAUTH_TOKEN"]},
    "excel": {"priority": 11, "requires": []},
}
```

---

### 4.8 ILanguagePack

**Purpose:** Abstract language-specific resources

```python
class ILanguagePack(Protocol):
    """
    Language-specific resources for analysis.

    Implementations: SpanishPack, EnglishPack, PortuguesePack
    """

    @property
    def language_code(self) -> str:
        """ISO 639-1 code (es, en, pt)."""
        ...

    def get_sentiment_lexicon(self) -> Dict[str, float]:
        """Word -> sentiment score mapping."""
        ...

    def get_emotion_categories(self) -> List[str]:
        """Emotion category names in this language."""
        ...

    def get_modifiers(self) -> "ModifierConfig":
        """Negation words, intensifiers, etc."""
        ...

    def get_churn_patterns(self) -> Dict[str, List[str]]:
        """Exit threat, competitor patterns."""
        ...

    def get_pain_point_keywords(self) -> Dict[str, List[str]]:
        """Category -> keyword patterns."""
        ...

    def get_stop_words(self) -> Set[str]:
        """Words to filter from keyword extraction."""
        ...


@dataclass
class ModifierConfig:
    negation_words: List[str]
    intensifiers: Dict[str, float]  # word -> boost factor
    diminishers: Dict[str, float]   # word -> reduction factor
    sarcasm_indicators: List[str]
    temporal_contrast_pairs: List[Tuple[str, str]]
```

---

### 4.9 IStorage

**Purpose:** Abstract file/object storage

```python
class IStorage(Protocol):
    """
    Vendor-agnostic storage abstraction (fsspec-style).

    Implementations: Local, S3, GCS, Azure, MinIO
    """

    def read(self, uri: str) -> pa.Table:
        """Read Arrow Table from URI."""
        # Supports: file://, s3://, gs://, abfss://
        ...

    def write(self, uri: str, data: pa.Table) -> None:
        """Write Arrow Table to URI."""
        ...

    def exists(self, uri: str) -> bool:
        """Check if object exists."""
        ...

    def list(self, uri: str, pattern: str = "*") -> List[str]:
        """List objects matching pattern."""
        ...

    def delete(self, uri: str) -> bool:
        """Delete object."""
        ...

    @property
    def storage_id(self) -> str:
        """Unique identifier."""
        ...
```

---

## 5. INPUT SPECIFICATIONS

### 5.1 Required Input Schema

The system SHALL accept input with minimum schema:

```python
REQUIRED_COLUMNS = {
    "rating": {
        "type": "numeric",
        "range": [0, 10],
        "nullable": True,
        "aliases": ["Nota", "NPS", "Score", "Rating", "Puntuacion"]
    },
    "comment": {
        "type": "string",
        "nullable": False,
        "min_length": 1,
        "aliases": [
            "Comentario Final", "Feedback", "Comment",
            "Review", "Comentario del Cliente", "Texto"
        ]
    }
}
```

### 5.2 Supported File Formats

| Format | Extensions | Engine |
|--------|------------|--------|
| CSV | .csv | Arrow CSV reader |
| TSV | .tsv | Arrow CSV reader (tab delimiter) |
| Excel | .xls, .xlsx | openpyxl/xlrd -> Arrow |
| Parquet | .parquet | Arrow native |
| JSON Lines | .jsonl | Arrow JSON reader |

### 5.3 Encoding Fallback Chain

For CSV/TSV files:

```python
ENCODING_CHAIN = [
    "utf-8",
    "utf-8-sig",  # UTF-8 with BOM
    "latin-1",    # Spanish-optimized
    "iso-8859-1",
    "cp1252",     # Windows Western European
]
```

### 5.4 File Constraints

```python
FILE_CONSTRAINTS = {
    "max_size_mb": 100,
    "max_rows": 1_000_000,
    "max_columns": 100,
    "min_rows": 1,
}
```

### 5.5 Schema Detection

The system SHALL auto-detect column mappings with confidence scoring:

```python
SCHEMA_CONFIDENCE_THRESHOLDS = {
    "auto_approve": 0.85,      # >= 0.85: proceed without confirmation
    "production_min": 0.70,    # >= 0.70: acceptable with warning
    "development_min": 0.60,   # >= 0.60: acceptable in dev
    "reject": 0.50,            # < 0.50: reject, require manual mapping
}
```

---

## 6. OUTPUT SPECIFICATIONS

### 6.1 Output Schema (36 Columns)

The system SHALL produce output with exactly 36 columns organized in 7 groups:

#### Group 1: Primary Review (10 columns)

| # | Column | Type | Range | Description |
|---|--------|------|-------|-------------|
| 1 | user_score | float | 0-10 | Original user rating |
| 2 | customer_comment | string | - | Original feedback text |
| 3 | ai_sentiment | float | 0-10 | AI-calculated sentiment |
| 4 | analysis_score | float | 0-10 | Intelligent score selection |
| 5 | score_source | string | - | Explanation of score choice |
| 6 | sentiment_category | enum | Positive/Neutral/Negative | Category from score |
| 7 | emotion | string | - | Dominant emotion detected |
| 8 | churn_risk | int | 0-100 | Churn probability score |
| 9 | review_priority_score | int | 0-100 | Triage priority |
| 10 | pain_point_primary | string | - | Primary pain point category |

#### Group 2: Secondary Analysis (7 columns)

| # | Column | Type | Description |
|---|--------|------|-------------|
| 11 | pain_point_secondary | string | Secondary pain point |
| 12 | pain_point_keywords | string | Comma-separated keywords |
| 13 | sentiment_alignment | float | User vs AI alignment (0-1) |
| 14 | actionability_score | float | How actionable (0-1) |
| 15 | word_count | int | Words in comment |
| 16 | has_deep_insights | bool | Full AI analysis flag |
| 17 | deep_insights_json | json | Structured insights |

#### Group 3: Duplicate Detection (5 columns)

| # | Column | Type | Description |
|---|--------|------|-------------|
| 18 | is_duplicate | bool | Exact duplicate flag |
| 19 | duplicate_count | int | Times this text appears |
| 20 | duplicate_group_id | int | Group ID (-1 if unique) |
| 21 | first_occurrence_id | int | Index of first occurrence |
| 22 | is_first_occurrence | bool | Is this the first |

#### Group 4: Quality Control (3 columns)

| # | Column | Type | Description |
|---|--------|------|-------------|
| 23 | quality_flags | string | Comma-separated flags |
| 24 | analysis_tier | enum | FULL_AI (always) |
| 25 | issues_detected | string | Problems found |

#### Group 5: AI Correction (4 columns)

| # | Column | Type | Description |
|---|--------|------|-------------|
| 26 | original_user_score | float | Score before correction |
| 27 | sentiment_before_correction | float | AI score before check |
| 28 | discrepancy_flag | bool | Large gap detected |
| 29 | discrepancy_explanation | string | Why scores differ |

#### Group 6: Technical (2 columns)

| # | Column | Type | Description |
|---|--------|------|-------------|
| 30 | sentiment_score_raw | float | Raw GPT sentiment |
| 31 | confidence_score | float | Analysis confidence (0-1) |

#### Group 7: Churn Extended (5 columns)

| # | Column | Type | Description |
|---|--------|------|-------------|
| 32 | churn_temporal_urgency | string | Urgency level |
| 33 | churn_competitor | string | Competitors mentioned |
| 34 | churn_competitor_context | string | Context of mention |
| 35 | churn_recommended_action | string | Suggested response |
| 36 | churn_reasoning | string | Why this risk level |

### 6.2 Schema Version

```python
OUTPUT_SCHEMA_VERSION = "1.0.0"

# Semantic versioning rules:
# MAJOR: Breaking changes (column removed/renamed)
# MINOR: New columns added (backward compatible)
# PATCH: Bug fixes (no schema change)
```

---

## 7. DOMAIN ALGORITHMS

### 7.1 Text Normalization

**Purpose:** Canonical text form for consistent processing

```python
def normalize_text(text: str) -> str:
    """
    Input: Raw text (any encoding, whitespace)
    Output: Normalized string

    Algorithm:
    1. Apply Unicode NFC normalization
    2. Convert to lowercase
    3. Strip leading/trailing whitespace
    4. Collapse multiple spaces to single space
    """
    import unicodedata
    normalized = unicodedata.normalize('NFC', text)
    normalized = normalized.lower()
    normalized = normalized.strip()
    normalized = ' '.join(normalized.split())
    return normalized
```

### 7.2 Duplicate Detection

**Purpose:** Identify exact and near-duplicate comments

#### 7.2.1 Exact Duplicates

```python
def detect_exact_duplicates(comments: List[str]) -> Dict[str, List[int]]:
    """
    Algorithm:
    1. Normalize each comment
    2. Calculate SHA256 hash (first 16 chars)
    3. Group indices by hash

    Output: {hash: [indices]} for hashes with len > 1
    """
    import hashlib

    groups = defaultdict(list)
    for idx, comment in enumerate(comments):
        normalized = normalize_text(comment)
        hash_key = hashlib.sha256(normalized.encode()).hexdigest()[:16]
        groups[hash_key].append(idx)

    return {k: v for k, v in groups.items() if len(v) > 1}
```

#### 7.2.2 Near-Duplicates

```python
def detect_near_duplicates(
    comments: List[str],
    threshold: float = 0.95
) -> List[Tuple[int, int, float]]:
    """
    Algorithm:
    1. For each pair (i, j) where j > i
    2. Calculate SequenceMatcher ratio
    3. If ratio >= threshold, record as near-duplicate

    Complexity: O(n^2) - use only on pre-filtered subsets
    """
    from difflib import SequenceMatcher

    pairs = []
    normalized = [normalize_text(c) for c in comments]

    for i in range(len(normalized)):
        for j in range(i + 1, len(normalized)):
            ratio = SequenceMatcher(None, normalized[i], normalized[j]).ratio()
            if ratio >= threshold:
                pairs.append((i, j, ratio))

    return pairs
```

### 7.3 Sentiment Analysis (Local NLP)

**Purpose:** Calculate sentiment score from lexicon

```python
def calculate_sentiment(
    text: str,
    language_pack: ILanguagePack
) -> Tuple[float, str]:
    """
    Input: Normalized text, language pack
    Output: (score 0-10, category)

    Algorithm:
    1. Tokenize text (word-level)
    2. Lookup each word in lexicon
    3. Apply modifiers (negation, intensifiers, etc.)
    4. Aggregate to sentence score
    5. Normalize to 0-10 scale
    """
    lexicon = language_pack.get_sentiment_lexicon()
    modifiers = language_pack.get_modifiers()

    tokens = text.lower().split()
    scores = []

    for i, token in enumerate(tokens):
        if token in lexicon:
            score = lexicon[token]

            # Check for negation in previous 3 words
            window = tokens[max(0, i-3):i]
            if any(w in modifiers.negation_words for w in window):
                score = 10 - score  # Flip polarity

            # Check for intensifiers
            if i > 0 and tokens[i-1] in modifiers.intensifiers:
                score *= modifiers.intensifiers[tokens[i-1]]

            scores.append(score)

    if not scores:
        return 5.0, "Neutral"  # Default neutral

    final_score = sum(scores) / len(scores)
    final_score = max(0, min(10, final_score))  # Clamp to 0-10

    # Categorize
    if final_score >= 7.0:
        category = "Positive"
    elif final_score >= 4.0:
        category = "Neutral"
    else:
        category = "Negative"

    return final_score, category
```

**Sentiment Thresholds:**

```python
SENTIMENT_THRESHOLDS = {
    "positive_min": 7.0,   # >= 7.0 = Positive
    "neutral_min": 4.0,    # >= 4.0 and < 7.0 = Neutral
                           # < 4.0 = Negative
}

SENTIMENT_MODIFIERS = {
    "negation_flip": 0.5,           # Subtract 50% of base
    "intensifier_boost": 1.15,      # +15%
    "sarcasm_penalty": 0.85,        # -15%
    "conditional_reduction": 0.90,  # -10%
    "temporal_contrast": 0.80,      # -20%
}
```

### 7.4 NPS Calculation

**Purpose:** Categorize as Promoter/Passive/Detractor

```python
def calculate_nps_category(rating: float) -> str:
    """
    Input: User rating 0-10
    Output: "promoter" | "passive" | "detractor"

    Thresholds:
    - Promoter: 9-10
    - Passive: 7-8
    - Detractor: 0-6
    """
    if rating >= 9:
        return "promoter"
    elif rating >= 7:
        return "passive"
    else:
        return "detractor"


def calculate_nps_score(
    promoters: int,
    passives: int,
    detractors: int,
    method: str = "shifted"
) -> float:
    """
    Methods:
    - shifted: (base + 1) * 50, range 0-100
    - standard: (P - D) / total * 100, range -100 to +100
    - absolute: abs(standard)
    - weighted: includes passive weight
    """
    total = promoters + passives + detractors
    if total == 0:
        return 50.0  # Neutral default

    base = (promoters - detractors) / total

    if method == "shifted":
        return (base + 1) * 50
    elif method == "standard":
        return base * 100
    elif method == "absolute":
        return abs(base * 100)
    elif method == "weighted":
        passive_weight = 0.5
        return (promoters - detractors + (passives * passive_weight)) / total * 100

    return (base + 1) * 50  # Default to shifted
```

### 7.5 Churn Risk Calculation

**Purpose:** Score likelihood of customer leaving (0-100)

```python
def calculate_churn_risk(
    user_score: float,
    comment: str,
    sentiment_alignment: float,
    language_pack: ILanguagePack
) -> Dict:
    """
    Output: {
        "score": 0-100,
        "level": "CRITICAL|HIGH|MEDIUM|LOW",
        "temporal_urgency": str,
        "competitors": str,
        "competitor_context": str,
        "recommendation": str,
        "reasoning": str,
        "confidence": 0-1
    }
    """
    patterns = language_pack.get_churn_patterns()

    # Base score from rating (inverted: low rating = high risk)
    base_score = (10 - user_score) * 10

    # Behavioral signals
    behavioral = 0
    has_exit_threat = any(
        re.search(p, comment, re.IGNORECASE)
        for p in patterns["exit_threat"]
    )
    has_competitor = any(
        re.search(p, comment, re.IGNORECASE)
        for p in patterns["competitor_mention"]
    )

    if has_exit_threat:
        behavioral += 30
        if has_competitor:
            behavioral += 10  # Combined threat boost
    if has_competitor:
        behavioral += 15

    # Technical signals
    technical = 0
    has_technical = any(
        re.search(p, comment, re.IGNORECASE)
        for p in patterns["technical_failure"]
    )
    has_recurring = any(
        re.search(p, comment, re.IGNORECASE)
        for p in patterns["recurring_issue"]
    )

    if has_technical:
        technical += 15
    if has_recurring:
        technical += 10

    # Economic signals
    economic = 0
    has_cost = any(
        re.search(p, comment, re.IGNORECASE)
        for p in patterns["cost_concern"]
    )

    if has_cost:
        economic += 10
        if has_exit_threat:
            economic += 5  # Cost + exit boost

    # Sentiment signals
    sentiment_penalty = 0
    if sentiment_alignment < 0.7:
        sentiment_penalty += 5

    # Calculate total
    total = base_score + behavioral + technical + economic + sentiment_penalty

    # Apply override rules
    total = apply_churn_override_rules(
        total, comment, user_score,
        has_exit_threat, has_competitor, has_technical, has_cost, has_recurring,
        patterns
    )

    # Clamp to 0-100
    total = max(0, min(100, total))

    # Determine level
    if total >= 80:
        level = "CRITICAL"
    elif total >= 60:
        level = "HIGH"
    elif total >= 40:
        level = "MEDIUM"
    else:
        level = "LOW"

    return {
        "score": total,
        "level": level,
        "temporal_urgency": detect_temporal_urgency(comment, patterns),
        "competitors": extract_competitors(comment, patterns),
        "competitor_context": extract_competitor_context(comment, patterns),
        "recommendation": generate_recommendation(level, has_exit_threat, has_competitor, has_cost, has_technical),
        "reasoning": generate_reasoning(base_score, behavioral, technical, economic, sentiment_penalty),
        "confidence": calculate_churn_confidence(has_exit_threat, has_competitor, has_technical, has_cost, len(comment.split()))
    }
```

**Churn Override Rules:**

```python
def apply_churn_override_rules(
    score: int,
    comment: str,
    user_score: float,
    has_exit: bool,
    has_competitor: bool,
    has_technical: bool,
    has_cost: bool,
    has_recurring: bool,
    patterns: Dict
) -> int:
    """
    6 override rules that can boost score regardless of components.
    """

    # RULE 1: Already churned (past tense)
    already_churned = [r'\b(decidi|cancele|di de baja|me fui)\b']
    if any(re.search(p, comment, re.IGNORECASE) for p in already_churned):
        score = max(score, 95)

    # RULE 2: Imminent cancellation
    imminent = [r'\b(voy a cancelar|apenas pueda|manana cancelo)\b']
    if any(re.search(p, comment, re.IGNORECASE) for p in imminent):
        score = max(score, 90)

    # RULE 3: High score + exit threat (contradiction = serious)
    if user_score >= 7 and has_exit:
        score = max(score, 85)

    # RULE 4: Low score + technical failure
    if user_score <= 3 and has_technical:
        score = max(score, 75)

    # RULE 5: Triple threat (exit + competitor + cost)
    if has_exit and has_competitor and has_cost:
        score = max(score, 90)

    # RULE 6: Escalation pattern (recurring + exit)
    if has_recurring and has_exit:
        score = int(score * 1.1)  # 10% boost

    return score
```

### 7.6 Pain Point Classification

**Purpose:** Categorize feedback into 21 pain point categories

```python
PAIN_POINT_TAXONOMY = {
    # Core Service (6)
    "CONNECTIVITY": "Connection drops, outages",
    "SPEED": "Slow internet, bandwidth",
    "RELIABILITY": "Frequent failures, instability",
    "COVERAGE": "Signal strength, geographic reach",
    "LATENCY": "Lag, ping, delay",
    "EQUIPMENT": "Router, modem, hardware",

    # Customer Experience (8)
    "SATISFACTION": "General sentiment",
    "SUPPORT_QUALITY": "Customer service quality",
    "GENERAL_QUALITY": "Vague 'improve service'",
    "RESPONSE_TIME": "Slow support response",
    "INSTALLATION": "Setup, activation",
    "COMMUNICATION": "Notifications, updates",
    "ATTITUDE": "Staff behavior",
    "PROCESS": "Procedures, bureaucracy",

    # Billing (4)
    "BILLING": "Billing errors, charges",
    "PRICING": "Price complaints",
    "PAYMENT": "Payment methods, discounts",
    "CONTRACT": "Terms, plan changes",

    # Business Risk (3)
    "CHURN_INTENT": "Cancellation intent",
    "COMPETITIVE_PRESSURE": "Competitor mentions",
    "TRUST": "Broken promises, misleading",
}


def classify_pain_points(
    text: str,
    language_pack: ILanguagePack
) -> Tuple[str, str, List[str]]:
    """
    Output: (primary_category, secondary_category, matched_keywords)

    Algorithm:
    1. Normalize text
    2. Count keyword matches per category
    3. Apply priority rules (PRICING > BILLING)
    4. Apply deduplication rules
    5. Return top 2 categories
    """
    keywords = language_pack.get_pain_point_keywords()
    text_lower = text.lower()

    scores = defaultdict(int)
    matched = defaultdict(list)

    for category, words in keywords.items():
        for word in words:
            if re.search(rf'\b{re.escape(word)}\b', text_lower):
                scores[category] += 1
                matched[category].append(word)

    # Priority: PRICING > BILLING
    if scores["PRICING"] > 0 and scores["BILLING"] > 0:
        scores["PRICING"] *= 2

    # Deduplication: SATISFACTION > GENERAL_QUALITY
    if scores["SATISFACTION"] > 0 and scores["GENERAL_QUALITY"] > 0:
        scores["GENERAL_QUALITY"] = 0

    # Sort by score
    sorted_cats = sorted(scores.items(), key=lambda x: -x[1])

    primary = sorted_cats[0][0] if sorted_cats else "OTHER"
    secondary = sorted_cats[1][0] if len(sorted_cats) > 1 else ""

    all_keywords = []
    for cat in [primary, secondary]:
        if cat:
            all_keywords.extend(matched[cat])

    return primary, secondary, all_keywords
```

### 7.7 Analysis Score Selection

**Purpose:** Intelligently select best score for analysis

```python
def select_analysis_score(
    user_score: Optional[float],
    ai_sentiment: Optional[float],
    gpt_corrected: Optional[float] = None
) -> Tuple[float, str]:
    """
    Output: (selected_score, explanation)

    Decision tree:
    1. No scores -> (None, "No data")
    2. Only AI -> (ai, "AI Sentiment (no user score)")
    3. Only user -> (user, "User (no AI analysis)")
    4. Both, gap < 2.0 -> (user, "User (validated by AI)")
    5. Both, gap 2.0-4.9 -> (user, "User (slight mismatch)")
    6. Both, gap >= 5.0, corrected -> (corrected, "GPT-4o (resolved)")
    7. Both, gap >= 5.0, no correction -> (user, "User (conflict, gap=X)")
    """
    if user_score is None and ai_sentiment is None:
        return None, "No data"

    if user_score is None:
        return ai_sentiment, "AI Sentiment (no user score)"

    if ai_sentiment is None:
        return user_score, "User (no AI analysis)"

    gap = abs(user_score - ai_sentiment)

    if gap < 2.0:
        return user_score, "User (validated by AI)"

    if gap < 5.0:
        return user_score, "User (slight sentiment mismatch)"

    # Large conflict
    if gpt_corrected is not None:
        return gpt_corrected, "GPT-4o (resolved conflict)"

    return user_score, f"User (conflict detected, gap={gap:.1f})"
```

### 7.8 Review Priority Scoring

**Purpose:** Score for triage prioritization (0-100)

```python
def calculate_review_priority(
    user_score: float,
    churn_risk: int,
    has_exit_threat: bool,
    actionability: float
) -> int:
    """
    Components:
    - Rating contribution: 0-40 points
    - Churn contribution: 0-30 points
    - Exit threat: 0-20 points
    - Actionability: 0-10 points
    """
    priority = 0

    # Rating (lower = more urgent)
    if user_score <= 3:
        priority += 40
    elif user_score <= 5:
        priority += 30
    elif user_score <= 7:
        priority += 20

    # Churn risk
    if churn_risk >= 80:
        priority += 30
    elif churn_risk >= 60:
        priority += 20
    elif churn_risk >= 40:
        priority += 10

    # Exit threat
    if has_exit_threat:
        priority += 20

    # Actionability
    priority += int(actionability * 10)

    return max(0, min(100, priority))
```

**Priority Levels:**

```python
PRIORITY_LEVELS = {
    "URGENT": (80, 100),   # Review immediately
    "HIGH": (60, 79),      # Review within 24h
    "MEDIUM": (40, 59),    # Review within 3 days
    "LOW": (0, 39),        # Standard review
}
```

---

## 8. AI INTEGRATION

### 8.1 Analysis Prompt

The system SHALL use the following prompt template for LLM analysis:

```python
ANALYSIS_SYSTEM_PROMPT = """You are a Spanish customer feedback analyst for telecommunications companies.

TASK: Analyze each customer comment and return structured JSON.

GUIDELINES:
1. Detect emotions on a 0.0-1.0 scale
2. Identify pain points from the taxonomy
3. Extract actionable keywords
4. Assess churn indicators
5. Be culturally aware of Latin American Spanish expressions

OUTPUT SCHEMA:
{
  "analyses": [
    {
      "comment_index": 0,
      "emotions": {
        "satisfaccion": 0.0-1.0,
        "confianza": 0.0-1.0,
        "anticipacion": 0.0-1.0,
        "frustracion": 0.0-1.0,
        "enojo": 0.0-1.0,
        "decepcion": 0.0-1.0,
        "confusion": 0.0-1.0
      },
      "sentiment_score": 0.0-10.0,
      "pain_points": ["CATEGORY1", "CATEGORY2"],
      "keywords": ["keyword1", "keyword2"],
      "churn_indicators": {
        "exit_intent": true/false,
        "competitor_mention": true/false,
        "urgency": "high/medium/low/none"
      },
      "quality": {
        "specificity": 0.0-1.0,
        "actionability": 0.0-1.0
      }
    }
  ]
}

PAIN POINT CATEGORIES:
- CONNECTIVITY, SPEED, RELIABILITY, COVERAGE, LATENCY, EQUIPMENT
- SATISFACTION, SUPPORT_QUALITY, RESPONSE_TIME, INSTALLATION
- BILLING, PRICING, PAYMENT, CONTRACT
- CHURN_INTENT, COMPETITIVE_PRESSURE, TRUST

EMOTION DEFINITIONS:
- satisfaccion: Happiness with service
- confianza: Trust in company
- anticipacion: Expectation (positive or negative)
- frustracion: Blocked goals
- enojo: Anger at service/company
- decepcion: Unmet expectations
- confusion: Unclear about service/process"""
```

### 8.2 Discrepancy Resolution Prompt

For comments where user score and AI sentiment differ by >= 5.0:

```python
DISCREPANCY_PROMPT = """Analyze why user rating ({user_score}/10) differs from AI sentiment ({ai_score}/10).

COMMENT: "{comment}"

INVESTIGATE:
1. Sarcasm/irony detection
2. Cultural expressions
3. Temporal contrast ("before good, now bad")
4. Inverted scale interpretation
5. Mixed signals in same comment

OUTPUT:
{
  "corrected_score": 0.0-10.0,
  "explanation": "reason for correction",
  "detected_patterns": ["sarcasm", "temporal_contrast", etc.],
  "confidence": 0.0-1.0,
  "needs_human_review": true/false
}"""
```

### 8.3 Batch Configuration

```python
LLM_BATCH_CONFIG = {
    "default_batch_size": 50,
    "max_batch_size": 150,
    "min_batch_size": 10,
    "timeout_seconds": 120,
    "max_retries": 3,
    "backoff_factor": 2,
    "temperature": 0.1,
    "max_tokens": 4096,
}
```

---

## 9. CACHING STRATEGY

### 9.1 Two-Tier Architecture

```
Tier 1: HOT CACHE (ICache implementation)
  |-- TTL: 7 days (configurable)
  |-- Purpose: Fast access, session persistence
  |-- Key format: "analysis:cache:{language}:{hash16}"
  |
Tier 2: COLD STORAGE (IStorage implementation)
  |-- TTL: Permanent (configurable retention)
  |-- Purpose: Cost savings across restarts
  |-- Path format: {cache_dir}/{language}/{hash}.parquet
```

### 9.2 Cache Key Generation

```python
def generate_cache_key(comment: str, language: str) -> str:
    """
    1. Normalize comment
    2. Prepend language code
    3. SHA256 hash
    4. Take first 16 hex chars
    """
    import hashlib
    normalized = normalize_text(comment)
    content = f"{language}:{normalized}"
    hash_hex = hashlib.sha256(content.encode()).hexdigest()[:16]
    return f"analysis:cache:{language}:{hash_hex}"
```

### 9.3 Cache Schema

```python
CACHE_SCHEMA_VERSION = "1.0.0"

CACHE_ENTRY_SCHEMA = {
    "comment_hash": str,      # 16-char hex
    "comment": str,           # Original text
    "language": str,          # ISO code
    "analysis": {
        # All analysis fields EXCEPT nps_category
        # NPS is recomputed from rating for ground truth
    },
    "metadata": {
        "model": str,
        "timestamp": str,
        "schema_version": str,
        "tokens_input": int,
        "tokens_output": int,
        "reuse_count": int,
    }
}
```

### 9.4 Critical Cache Rule

```python
# NPS CATEGORY SHALL NEVER BE CACHED
# It is always recomputed from user rating to ensure ground truth accuracy

def cache_analysis(analysis: Dict) -> Dict:
    cached = analysis.copy()
    cached.pop("nps_category", None)
    return cached

def restore_analysis(cached: Dict, user_rating: float) -> Dict:
    restored = cached.copy()
    restored["nps_category"] = calculate_nps_category(user_rating)
    return restored
```

---

## 10. CONTAINER ARCHITECTURE

### 10.1 Nucleic Container Concept

The system SHALL be deployable as a single container with multiple services:

```
NUCLEIC CONTAINER
  |
  +-- Service 1: API Gateway (FastAPI/Starlette)
  |     Port: 8000
  |     Endpoints: /api/upload, /api/task, /api/export
  |
  +-- Service 2: Worker (Compute Orchestrator)
  |     Handles: Batch processing, AI calls
  |     Uses: IComputeOrchestrator implementation
  |
  +-- Service 3: Cache (embedded or sidecar)
  |     Uses: ICache implementation
  |     Default: DragonflyDB or Redis
  |
  +-- Service 4: Event Stream (embedded or sidecar)
  |     Uses: IEventStream implementation
  |     Default: Redpanda or NATS
  |
  +-- Service 5: Observability Collector
       Uses: IObservability implementation
       Default: OpenTelemetry Collector
```

### 10.2 Container Orchestration Agnostic

The container specification SHALL work with:

- Docker Compose (development, single-node)
- Podman (rootless, security-focused)
- Kubernetes (multi-node, orchestrated)
- Docker Swarm (simple clustering)

### 10.3 Service Discovery

Internal services SHALL communicate via:

```python
SERVICE_DISCOVERY = {
    "method": "environment",  # or "dns", "consul", "k8s"
    "api_host": "${API_HOST:-localhost}",
    "api_port": "${API_PORT:-8000}",
    "cache_host": "${CACHE_HOST:-localhost}",
    "cache_port": "${CACHE_PORT:-6379}",
    "stream_host": "${STREAM_HOST:-localhost}",
    "stream_port": "${STREAM_PORT:-9092}",
}
```

### 10.4 Health Endpoints

Every service SHALL expose:

```python
HEALTH_ENDPOINTS = {
    "/health": "Basic alive check",
    "/ready": "Ready to accept traffic",
    "/live": "Liveness (for K8s)",
}
```

---

## 11. OBSERVABILITY

### 11.1 Metrics to Collect

```python
REQUIRED_METRICS = {
    # Processing metrics
    "feedback_processed_total": "counter",
    "feedback_processing_seconds": "histogram",
    "batch_size": "histogram",

    # Cache metrics
    "cache_hits_total": "counter",
    "cache_misses_total": "counter",
    "cache_hit_rate": "gauge",

    # LLM metrics
    "llm_requests_total": "counter",
    "llm_tokens_input_total": "counter",
    "llm_tokens_output_total": "counter",
    "llm_cost_usd_total": "counter",
    "llm_latency_seconds": "histogram",

    # Error metrics
    "errors_total": "counter",
    "errors_by_type": "counter",
}
```

### 11.2 Trace Spans

```python
REQUIRED_TRACES = [
    "upload_file",
    "detect_schema",
    "normalize_text",
    "detect_duplicates",
    "analyze_batch",
    "llm_api_call",
    "cache_lookup",
    "cache_store",
    "calculate_metrics",
    "export_results",
]
```

### 11.3 Event Topics

```python
EVENT_TOPICS = {
    "feedback.uploaded": "File uploaded, processing started",
    "feedback.validated": "Schema validated, ready for analysis",
    "feedback.batch_completed": "Batch analysis finished",
    "feedback.analyzed": "Full analysis complete",
    "feedback.exported": "Results exported",
    "feedback.error": "Error occurred",
}
```

---

## 12. VALIDATION CRITERIA

### 12.1 Output Accuracy Requirements

| Column | Tolerance | Validation Method |
|--------|-----------|-------------------|
| sentiment_category | 100% match | Enum validation |
| churn_risk | +/- 5 points | Range validation |
| nps_category | 100% match | Enum validation |
| pain_point_primary | 90% F1 score | Against labeled data |
| duplicate detection | 100% precision | Hash verification |

### 12.2 Performance Requirements

```python
PERFORMANCE_SLA = {
    "throughput_min": 40,      # comments/second
    "latency_p99_ms": 100,     # 99th percentile
    "cache_hit_rate_min": 0.4, # 40% minimum
    "error_rate_max": 0.01,    # 1% maximum
}
```

### 12.3 Test Dataset Requirements

Validation SHALL use test datasets with:

- Minimum 1,000 labeled comments
- Coverage of all 21 pain point categories
- Coverage of all churn risk levels
- At least 10% duplicates
- Multi-score range (0-10 distribution)

---

## 13. NON-FUNCTIONAL REQUIREMENTS

### 13.1 Scalability

```python
SCALE_REQUIREMENTS = {
    "min_dataset_rows": 1,
    "max_dataset_rows": 1_000_000,
    "concurrent_users": 10,
    "horizontal_scale": True,  # Add nodes
    "vertical_scale": True,    # Add resources
}
```

### 13.2 Reliability

```python
RELIABILITY_REQUIREMENTS = {
    "availability": 0.99,       # 99% uptime
    "mean_time_to_recovery": 300,  # 5 minutes
    "data_durability": 0.9999,  # 99.99%
    "graceful_degradation": True,
}
```

### 13.3 Security

```python
SECURITY_REQUIREMENTS = {
    "data_encryption_at_rest": True,
    "data_encryption_in_transit": True,
    "api_authentication": True,
    "audit_logging": True,
    "pii_handling": "configurable",  # mask, redact, or pass-through
}
```

---

## 14. CONFIGURATION REFERENCE

### 14.1 Environment Variables

```bash
# Application
APP_ENV=production|development|test
DEBUG=false
SECRET_KEY=min-32-char-secret

# Arrow/Storage
STORAGE_URI=file:///data  # or s3://bucket or gs://bucket
PARQUET_COMPRESSION=zstd
ARROW_MEMORY_POOL=system  # system|jemalloc|mimalloc

# Pipeline Engine (DataFusion - recommended)
DATAFUSION_ENABLED=true
DATAFUSION_TARGET_PARTITIONS=4
DATAFUSION_BATCH_SIZE=8192
DATAFUSION_COALESCE_BATCHES=true

# Query Interface (DuckDB - for debug/observability)
DUCKDB_ENABLED=true
DUCKDB_DATABASE=:memory:  # or /path/to/analytics.duckdb
DUCKDB_THREADS=4

# Polars (optional DataFrame operations)
POLARS_ENABLED=false
POLARS_STREAMING=true

# Parallelism (Rust-based, not Python multiprocessing)
POLARS_MAX_THREADS=0           # 0 = auto-detect CPU cores (Rayon default)
DATAFUSION_TARGET_PARTITIONS=0 # 0 = auto-detect (Tokio default)
COMPUTE_BATCH_SIZE=50          # Batch size for LLM calls

# I/O Async (isolated, only for LLM calls)
HTTPX_TIMEOUT=120              # LLM API timeout
ANYIO_BACKEND=asyncio          # or trio if preferred

# Scale-out (only when single machine insufficient)
COMPUTE_ORCHESTRATOR=polars|datafusion|dask|ray
DASK_SCHEDULER=synchronous     # synchronous|threads|processes|distributed

# Cache (implementation-agnostic)
CACHE_IMPLEMENTATION=redis|valkey|dragonfly|local
CACHE_URI=redis://localhost:6379
CACHE_TTL_DAYS=7

# Event Stream (implementation-agnostic)
STREAM_IMPLEMENTATION=redpanda|kafka|nats|redis
STREAM_URI=localhost:9092

# Tunnel (implementation-agnostic)
TUNNEL_IMPLEMENTATION=cloudflare|tailscale|wireguard|caddy|nginx
TUNNEL_TOKEN=${TUNNEL_TOKEN}

# Observability (implementation-agnostic)
OBSERVABILITY_IMPLEMENTATION=otlp|prometheus|datadog|console
OTLP_ENDPOINT=http://localhost:4317

# LLM (implementation-agnostic)
LLM_PROVIDER=openai|anthropic|google|ollama
LLM_API_KEY=${LLM_API_KEY}
LLM_MODEL=gpt-4o-mini
LLM_TIMEOUT=120
LLM_ROUTING_STRATEGY=balanced|cost|latency|quality|failover

# Export
EXPORT_DEFAULT_FORMAT=parquet|csv|google_sheets
GOOGLE_OAUTH_TOKEN=/path/to/token.pickle
```

### 14.2 Feature Flags

```python
FEATURE_FLAGS = {
    "enable_near_duplicate_detection": True,
    "enable_discrepancy_correction": True,
    "enable_deep_insights": True,
    "enable_churn_recommendations": True,
    "enable_persistent_cache": True,
    "enable_parallel_processing": True,
}
```

---

## 15. DOMAIN DATA ASSETS

### 15.1 Spanish Sentiment Lexicon

The system SHALL include a Spanish sentiment lexicon with minimum 5,000 entries:

```python
# Sample structure (full lexicon in language pack)
SPANISH_LEXICON_SAMPLE = {
    # Positive (score 7-10)
    "excelente": 9.5,
    "fantastico": 9.0,
    "genial": 8.5,
    "bueno": 7.5,
    "satisfecho": 8.0,

    # Neutral (score 4-6.9)
    "normal": 5.0,
    "regular": 5.0,
    "aceptable": 5.5,

    # Negative (score 0-3.9)
    "malo": 2.0,
    "terrible": 0.5,
    "horrible": 0.5,
    "pesimo": 1.0,
    "frustrante": 2.5,
}
```

### 15.2 Pain Point Keywords

```python
PAIN_POINT_KEYWORDS = {
    "CONNECTIVITY": [
        "conexion", "conectar", "desconecta", "sin internet",
        "se cae", "caida", "intermitente", "inestable"
    ],
    "SPEED": [
        "lento", "velocidad", "rapido", "megas", "ancho de banda",
        "descarga", "carga", "streaming", "buffering"
    ],
    "RELIABILITY": [
        "falla", "funciona", "estable", "confiable",
        "problema", "error", "averia"
    ],
    "SUPPORT_QUALITY": [
        "atencion", "servicio al cliente", "soporte", "ayuda",
        "resolver", "solucion", "respuesta"
    ],
    "PRICING": [
        "precio", "caro", "costoso", "economico", "barato",
        "tarifa", "plan", "promocion", "descuento"
    ],
    "BILLING": [
        "factura", "cobro", "pago", "cargo", "doble cobro",
        "error en factura", "monto"
    ],
    "CHURN_INTENT": [
        "cancelar", "dar de baja", "cambiar", "otro proveedor",
        "me voy", "buscar alternativa"
    ],
    "COMPETITIVE_PRESSURE": [
        "tigo", "claro", "personal", "movistar", "copaco",
        "competencia", "otra empresa"
    ],
    # ... (complete dictionary in language pack)
}
```

### 15.3 Churn Patterns

```python
CHURN_PATTERNS = {
    "exit_threat": [
        r"\b(cancelar|dar de baja|cambiar proveedor)\b",
        r"\b(pensando en cambiar|considero cambiar)\b",
        r"\b(busco otro|buscar alternativa)\b",
        r"\b(me voy a ir|ya me canse)\b"
    ],
    "competitor_mention": [
        r"\b(tigo|claro|personal|movistar|copaco)\b",
        r"\b(otra empresa|competencia|alternativa)\b"
    ],
    "technical_failure": [
        r"\b(sin servicio|no funciona|caido|se cae)\b",
        r"\b(intermitente|cortes frecuentes)\b",
        r"\b(no hay internet|sin conexion)\b"
    ],
    "recurring_issue": [
        r"\b(todos los dias|cada dia|siempre)\b",
        r"\b(otra vez|de nuevo|constantemente)\b",
        r"\b(frecuente|repetido|mismo problema)\b"
    ],
    "cost_concern": [
        r"\b(caro|costoso|precio alto|muy caro)\b",
        r"\b(no puedo pagar|subio el precio)\b",
        r"\b(aumentaron|incremento)\b"
    ],
    "already_churned": [
        r"\b(decidi cancelar|ya cancele|di de baja)\b",
        r"\b(me cambie|ya me fui)\b"
    ],
    "imminent_churn": [
        r"\b(voy a cancelar|manana cancelo)\b",
        r"\b(apenas pueda|en cuanto pueda)\b"
    ]
}
```

### 15.4 Modifier Words

```python
SPANISH_MODIFIERS = {
    "negation": [
        "no", "nunca", "jamas", "tampoco", "ni",
        "sin", "nada", "ninguno", "nadie"
    ],
    "intensifiers": {
        "muy": 1.3,
        "demasiado": 1.4,
        "extremadamente": 1.5,
        "super": 1.3,
        "totalmente": 1.4,
        "completamente": 1.4,
        "absolutamente": 1.5
    },
    "diminishers": {
        "poco": 0.7,
        "algo": 0.8,
        "apenas": 0.6,
        "casi": 0.8
    },
    "sarcasm_indicators": [
        "claro que si", "por supuesto", "como no",
        "que bueno", "que bien", "genial"  # Often sarcastic in complaints
    ],
    "temporal_contrast": [
        ("antes", "ahora"),
        ("era", "es"),
        ("tenia", "tiene"),
        ("funcionaba", "funciona")
    ]
}
```

---

## APPENDIX A: Anti-Lock-In Checklist

| Layer | Interface | Primary (Recommended) | Alternative | Self-Hosted | Vendor Risk |
|-------|-----------|----------------------|-------------|-------------|-------------|
| Data Format | Arrow (unconditional) | - | - | Yes | None (Apache) |
| Pipeline Engine | IComputeOrchestrator | DataFusion | asyncio, Polars | Yes | None (Apache) |
| Cold Storage | IStorage | Parquet | Arrow IPC | Yes | None (Apache) |
| Query/Debug | - | DuckDB | DataFusion SQL | Yes | None (MIT) |
| Scale-Out | IComputeOrchestrator | Dask | Ray (risk accepted) | Yes | Low/HIGH |
| Tunnel | ITunnel | Cloudflare | Tailscale, Caddy | Yes | Low |
| Cache | ICache | Redis | Valkey, Dragonfly | Yes | Low |
| Events | IEventStream | Redpanda | Kafka, NATS | Yes | Low |
| LLM | ILLMProvider | OpenAI | Anthropic, Ollama | Yes | Medium |
| Storage | IStorage | Local | S3, GCS, MinIO | Yes | Low |
| Observability | IObservability | OTLP | Prometheus | Yes | None |

**Ray Risk Acceptance Protocol:**

If customer demands Ray, document acceptance of:
- License change risk (Apache -> BSL/SSPL precedent)
- Anyscale/Databricks acquisition risk
- Telemetry insertion risk
- API deprecation churn risk
- Documentation drift toward managed cloud

---

## APPENDIX B: Glossary

| Term | Definition |
|------|------------|
| Arrow | Apache Arrow columnar format - memory layout contract (unconditional core) |
| DataFusion | Apache-governed Rust query engine on Arrow - pipeline execution with optimization |
| DuckDB | MIT-licensed embedded OLAP database - query interface for debug/observability |
| Parquet | Arrow's native columnar file format - cold storage |
| Polars | Arrow-native DataFrame library (arrow-rs) - optional DataFrame operations |
| Substrait | Portable query plan format - enables cross-engine execution |
| Delegation Contract | Interface (Protocol) that abstracts vendor implementation |
| Nucleic Container | Single container with multiple services (not distributed) |
| Medallion Architecture | Bronze/Silver/Gold data layers |
| NPS | Net Promoter Score (Promoter/Passive/Detractor) |
| Pain Point | Category of customer complaint |
| Churn Risk | Probability of customer leaving (0-100) |
| Zero-Copy | Data sharing without serialization/deserialization overhead |

---

## APPENDIX C: Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-13 | Initial agnostic blueprint |
| 1.1.0 | 2025-12-14 | Refined stack: Arrow+DataFusion+Parquet+DuckDB. Ray demoted to "avoid unless forced". Added implementation hierarchy for IComputeOrchestrator. |
| 1.2.0 | 2025-12-14 | Portable parallelism fix: Rust-based (Polars/Rayon, DataFusion/Tokio) replaces Python multiprocessing. httpx+anyio for isolated async I/O. |

---

**END OF BLUEPRINT**

**Document Type:** Product Requirements Specification
**Confidentiality:** Internal Use
**Implementation:** Any developer can build from this specification without exposure to prior implementations

---

## APPENDIX D: LLM PROVIDER CONTRACT ALIGNMENT (2025-12-15)

### D.1 Interface Reconciliation

Section 4.6 (`ILLMProvider`) is aligned with the authoritative specification in `LLM_PROVIDER_CONTRACT.md`. Key updates:

#### D.1.1 Arrow-Native Input (Updated)

**Original (Section 4.6):**
```python
async def analyze_batch(
    self,
    comments: List[str],  # Python list
    language: str,
    schema: Dict
) -> List[AnalysisResult]
```

**Updated (LLM_PROVIDER_CONTRACT.md):**
```python
async def analyze_batch(
    self,
    request: AnalysisRequest  # Contains pa.Array
) -> List[AnalysisResult]

@dataclass
class AnalysisRequest:
    comments: pa.Array          # Arrow string array (zero-copy)
    language: str
    analysis_schema: Dict[str, Any]
```

**Rationale:** Arrow-native input enables zero-copy extraction from source table. Conversion to `List[str]` happens inside adapters at the API boundary only.

#### D.1.2 Enhanced ProviderCapabilities (Updated)

**Additional fields added:**

```python
@dataclass(frozen=True)
class ProviderCapabilities:
    # Original fields from Section 4.6
    supports_structured_output: bool
    supports_batch: bool
    supports_streaming: bool
    max_context_tokens: int
    max_output_tokens: int
    languages: List[str]
    cost_per_1k_input: float
    cost_per_1k_output: float

    # NEW FIELDS (LLM_PROVIDER_CONTRACT.md)
    provider_id: str              # Unique identifier for routing/logging
    supports_vision: bool         # Image input capability
    tokens_per_second: float      # Throughput estimate (0 = unknown)
    supports_prompt_caching: bool # OpenAI/Anthropic prompt cache
```

#### D.1.3 Health Check Method (Added)

```python
async def health_check(self) -> bool:
    """Is this provider available right now?"""
    ...
```

**Rationale:** Required for routing decisions. Router must know which providers are healthy before selecting.

### D.2 Local-First Default Strategy

Section 4.6 routing strategy is updated to prioritize local providers:

**Original:**
```python
def fallback_chain(self) -> List[str]:
    return ["openai", "anthropic", "google", "ollama"]
```

**Updated:**
```python
def fallback_chain(self) -> List[str]:
    return [
        "ollama",      # Local, free, default
        "vllm",        # Local, high-throughput
        "openai",      # Cloud, best structured output
        "anthropic",   # Cloud, best reasoning
    ]
```

### D.3 Adapter Classification

Adapters are now classified by API compatibility:

```
OpenAI-Compatible (thin adapter, ~50 lines):
├── OllamaAdapter
├── VLLMAdapter
├── LlamaCppAdapter
├── OpenAIAdapter
├── GroqAdapter
└── TogetherAdapter

Non-OpenAI (medium adapter, ~100-150 lines):
├── AnthropicAdapter    # Different message format
└── GeminiAdapter       # Different API structure

Direct Loading (thick adapter, ~200 lines):
├── TransformersAdapter # No server required
└── MLXAdapter          # Apple Silicon native
```

### D.4 Routing Strategies (Expanded)

```python
class RoutingStrategy(Enum):
    LOCAL_FIRST = "local_first"      # Default: try local, fallback to cloud
    COST_OPTIMIZED = "cost"          # Cheapest available provider
    LATENCY_OPTIMIZED = "latency"    # Fastest available provider
    QUALITY_OPTIMIZED = "quality"    # Best model available
    FAILOVER = "failover"            # Strict priority chain
```

### D.5 Configuration Update

```python
LLM_CONFIG = {
    "routing": {
        "strategy": "local_first",  # NEW DEFAULT
        "local_providers": ["ollama", "vllm", "llamacpp"],
        "cloud_providers": ["openai", "anthropic"],
    },
    "providers": {
        "ollama": {
            "enabled": True,         # Enabled by default
            "model": "llama3:8b",
            "priority": 1,           # Highest priority
        },
        "openai": {
            "enabled": False,        # Opt-in for cloud
            "api_key": "${OPENAI_API_KEY}",
            "priority": 10,
        },
    }
}
```

### D.6 Cross-Reference

For complete specification including adapter implementations, batch orchestration, and performance considerations:

```
📄 LLM_PROVIDER_CONTRACT.md (Authoritative Source)
```
