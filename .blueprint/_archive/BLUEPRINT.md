# Customer Feedback Analyzer - Product Blueprint

**Version:** 1.0.0
**Date:** 2025-12-13
**Status:** Authoritative Specification

---

## DOCUMENT PURPOSE

This document specifies WHAT the Customer Feedback Analyzer system does. It is written for implementation from scratch using any technology stack. All requirements use imperative language ("the system SHALL").

**Target Stack (Unconditional Core):**
- **Arrow:** Columnar data format, Flight RPC for streaming, Parquet for cold storage, medallion architecture
- **DataFusion:** Apache-governed query engine with algebraic optimization
- **Polars:** Rust-native DataFrame operations with Rayon parallelism
- **DuckDB:** SQL interface for debugging and observability
- **Cloudflare Tunnel:** Secure edge deployment (or Tailscale for self-hosted)
- **Docker:** Full containerization from day zero for any deployment scale

**Orchestration (Prefer Top to Bottom):**
1. Polars + httpx/anyio (default, single-machine)
2. DataFusion (pipeline optimization)
3. Dask (scale-out if needed)
4. Ray (ONLY if customer demands - see caveat below)

> **⚠️ RAY IS NEGLIGIBLE:** For self-deployed VM services processing typical feedback datasets (50-150MB, 125k rows), Ray is unnecessary—Polars processes in <2 seconds. Ray introduces Anyscale vendor risk and complexity. Only use Ray if customer explicitly demands it with documented risk acceptance. See `BLINDSPOTS.md` Section "Why Ray is Negligible" and `STRATEGY.md` "DECISION: Avoid Ray" for full rationale.

**Core Principle:** DELEGATION - own the contracts, swap the implementations. Zero vendor lock-in.

---

## TABLE OF CONTENTS

1. [System Overview](#1-system-overview)
2. [Input Specifications](#2-input-specifications)
3. [Output Specifications](#3-output-specifications)
4. [Domain Algorithms](#4-domain-algorithms)
5. [AI Integration Contract](#5-ai-integration-contract)
6. [Storage Architecture](#6-storage-architecture)
7. [Delegation Contracts](#7-delegation-contracts)
8. [Validation Criteria](#8-validation-criteria)
9. [Non-Functional Requirements](#9-non-functional-requirements)
10. [Configuration Parameters](#10-configuration-parameters)

---

## 1. SYSTEM OVERVIEW

### 1.1 Purpose

The system SHALL analyze customer feedback text to extract:
- Sentiment scores and categories
- Emotion detection (7 categories)
- Churn risk assessment
- Pain point classification (21 categories)
- NPS categorization
- Actionable insights for business operations

### 1.2 Capabilities

The system SHALL:
1. Accept feedback data in CSV, Excel, TSV, or Parquet formats
2. Detect and validate schema automatically
3. Normalize and deduplicate text
4. Analyze feedback using AI (with multi-provider support)
5. Calculate business metrics (churn risk, priority scores)
6. Export results to multiple formats
7. Cache analysis results for cost optimization
8. Scale from single machine to distributed cluster without code changes

### 1.3 Language Support

The system SHALL support Spanish (es) as the primary language with architecture ready for:
- English (en)
- Portuguese (pt)
- Additional languages via language pack pattern

---

## 2. INPUT SPECIFICATIONS

### 2.1 File Formats

The system SHALL accept:

| Format | Extensions | Max Size | Encoding |
|--------|------------|----------|----------|
| CSV | .csv | 100 MB | UTF-8, Latin-1, CP1252 |
| TSV | .tsv | 100 MB | UTF-8, Latin-1, CP1252 |
| Excel | .xls, .xlsx | 100 MB | Native |
| Parquet | .parquet | 100 MB | Native |

### 2.2 Required Schema

The system SHALL require minimum two columns:

**Rating Column** (one of):
- `Nota` (0-10 scale)
- `NPS` (0-10 scale)
- `Rating`, `Score`, `Puntuacion`, `Calificacion`

**Comment Column** (one of):
- `Comentario Final`
- `Comentario del Cliente`
- `Feedback`, `Comment`, `Review`, `Texto`

### 2.3 Schema Detection

The system SHALL:
1. Auto-detect columns using fuzzy matching (threshold: 0.70)
2. Auto-approve schema at confidence >= 0.85
3. Reject schema at confidence < 0.50
4. Support manual column mapping override

### 2.4 Input Validation

The system SHALL validate:
- File size <= 100 MB
- Row count <= 1,048,576 (Excel limit)
- Rating values in range 0-10
- Comment text is non-empty string

---

## 3. OUTPUT SPECIFICATIONS

### 3.1 Output Schema (36 Columns)

The system SHALL produce exactly 36 output columns in 7 groups:

**GROUP 1: Primary Review (10 columns)**

| Column | Type | Range | Description |
|--------|------|-------|-------------|
| User Score | float | 0-10 | Original user rating |
| Customer Comment | string | - | Original feedback text |
| AI Sentiment | float | 0-10 | AI-calculated sentiment |
| Analysis Score | float | 0-10 | Intelligent score selection |
| Score Source | string | - | Explanation of score choice |
| Sentiment Category | enum | Positive/Neutral/Negative | Category from score |
| Emotion | string | - | Dominant emotion |
| Churn Risk | int | 0-100 | Churn probability score |
| Review Priority Score | int | 0-100 | Triage priority |
| Pain Point Category (Primary) | string | - | Main issue category |

**GROUP 2: Secondary Analysis (7 columns)**

| Column | Type | Range | Description |
|--------|------|-------|-------------|
| Pain Point Category (Secondary) | string | - | Secondary issue |
| Pain Point Keywords | string | - | Comma-separated keywords |
| Sentiment Score Alignment | float | 0-1 | User vs AI agreement |
| Actionability Score | float | 0-1 | How actionable |
| Word Count | int | 0+ | Words in comment |
| Has Deep Insights | bool | - | Has JSON insights |
| Deep Insights JSON | string | - | Structured insights |

**GROUP 3: Duplicate Detection (5 columns)**

| Column | Type | Description |
|--------|------|-------------|
| Is Duplicate | bool | Exact duplicate flag |
| Duplicate Count | int | Count of duplicates |
| Duplicate Group ID | int | Group identifier (-1 if unique) |
| First Occurrence ID | int | Index of first in group |
| Is First Occurrence | bool | Is this the first |

**GROUP 4: Quality Control (3 columns)**

| Column | Type | Description |
|--------|------|-------------|
| Quality Flags | string | Comma-separated flags |
| Analysis Tier | enum | Always "FULL_AI" |
| Problemas Detectados | string | Detected issues |

**GROUP 5: AI Correction (4 columns)**

| Column | Type | Description |
|--------|------|-------------|
| Original User Score | float | Pre-correction score |
| Sentiment Score (Before) | float | Pre-correction AI score |
| Discrepancy Flag | bool | Large gap detected |
| Discrepancy Explanation | string | Correction rationale |

**GROUP 6: Technical (2 columns)**

| Column | Type | Range | Description |
|--------|------|-------|-------------|
| Sentiment Score (AI) | float | 0-10 | Raw AI sentiment |
| Confidence Score | float | 0-1 | Analysis confidence |

**GROUP 7: Churn Extended (5 columns)**

| Column | Type | Description |
|--------|------|-------------|
| Churn Risk Temporal Urgency | string | Urgency level |
| Churn Risk Competitor | string | Mentioned competitors |
| Churn Risk Competitor Context | string | Competitor context |
| Churn Risk Recommended Action | string | Suggested action |
| Churn Risk Reasoning | string | Risk explanation |

### 3.2 Export Formats

The system SHALL export to:

**Primary (Always Available - Open Standards):**
1. **Parquet** - Columnar, compressed, any tool can read
2. **Arrow IPC** - Streaming, zero-copy, inter-process
3. **CSV** - Universal fallback, UTF-8 BOM

**Secondary (Optional - Cloud Wrappers):**
4. **Google Sheets** - 4-tab structure (requires OAuth)

### 3.3 Google Sheets Structure

When exporting to Google Sheets, the system SHALL create 4 tabs:

1. **Dashboard** - Executive summary with KPIs and charts
2. **Alta Prioridad** - High priority items (Priority Score >= 60)
3. **Analisis Comprimido** - Essential 12 columns for daily review
4. **Analisis Completo** - All 36 columns

---

## 4. DOMAIN ALGORITHMS

### 4.1 Text Normalization

The system SHALL normalize text by:
1. Applying Unicode NFC normalization
2. Converting to lowercase
3. Stripping leading/trailing whitespace
4. Collapsing multiple spaces to single space

```
Input:  "  El SERVICIO   es   MALO  "
Output: "el servicio es malo"
```

### 4.2 Duplicate Detection

**Exact Duplicates:**
1. Normalize comment text
2. Calculate SHA256 hash (first 16 chars)
3. Group by hash
4. Mark duplicates with group ID

**Near Duplicates:**
1. Compare normalized texts with similarity threshold 0.95
2. Use Jaccard word similarity for O(n) performance
3. Assign to same group if similarity >= threshold

### 4.3 Sentiment Analysis

The system SHALL calculate sentiment using:

**Thresholds:**
- Positive: score >= 7.0
- Neutral: 4.0 <= score < 7.0
- Negative: score < 4.0

**Modifiers:**
- Negation detection: flip polarity (-50%)
- Intensifiers ("muy", "demasiado"): +15%
- Sarcasm detection: -15%
- Conditional mood: -10%
- Temporal contrast ("antes", "ahora"): -20%

### 4.4 Emotion Detection

The system SHALL detect 7 emotions:

**Positive:** satisfaccion, confianza, anticipacion
**Negative:** frustracion, enojo, decepcion
**Neutral:** confusion

Each emotion SHALL be scored 0.0 to 1.0.

### 4.5 NPS Calculation

**Category Assignment:**
- Promoter: rating 9-10
- Passive: rating 7-8
- Detractor: rating 0-6

**Score Calculation (SHIFTED method):**
```
base_score = (promoters - detractors) / total
nps = (base_score + 1) * 50  # Range: 0-100
```

### 4.6 Churn Risk Calculation

**Risk Levels:**
- CRITICAL: 80-100
- HIGH: 60-79
- MEDIUM: 40-59
- LOW: 0-39

**Base Score:**
```
score = (10 - user_rating) * 10
```

**Signal Contributions:**
- Exit threat detected: +30 points
- Competitor mention: +15 points
- Technical failure: +15 points
- Recurring issue: +10 points
- Cost concern: +10 points

**Override Rules:**
1. Already churned ("cancele", "di de baja"): minimum 95
2. Imminent cancellation: minimum 90
3. Triple threat (exit + competitor + cost): minimum 90
4. High score + exit threat: minimum 85

### 4.7 Pain Point Classification

The system SHALL classify into 21 categories:

**Core Service (6):** CONNECTIVITY, SPEED, RELIABILITY, COVERAGE, LATENCY, EQUIPMENT

**Customer Experience (8):** SATISFACTION, SUPPORT_QUALITY, GENERAL_QUALITY, RESPONSE_TIME, INSTALLATION, COMMUNICATION, ATTITUDE

**Billing (4):** BILLING, PRICING, PAYMENT, CONTRACT

**Business Risk (4):** CHURN_INTENT, COMPETITIVE_PRESSURE, FRAUD_CONCERN, TRUST

**Catch-All (2):** GENERIC, OTHER

**Classification Algorithm:**
1. Normalize comment to lowercase
2. Match keywords per category (word boundary regex)
3. Score = count of keyword matches
4. Select top categories above threshold (2 matches minimum)
5. Apply priority: PRICING > BILLING when both present

### 4.8 Review Priority Score

**Calculation (0-100):**
```
priority = 0

# User rating contribution (0-40)
if rating <= 3: priority += 40
elif rating <= 5: priority += 30
elif rating <= 7: priority += 20

# Churn risk contribution (0-30)
if churn >= 80: priority += 30
elif churn >= 60: priority += 20
elif churn >= 40: priority += 10

# Exit threat contribution (0-20)
if has_exit_threat: priority += 20

# Actionability contribution (0-10)
priority += int(actionability * 10)
```

**Priority Levels:**
- URGENT: 80-100
- HIGH: 60-79
- MEDIUM: 40-59
- LOW: 0-39

---

## 5. AI INTEGRATION CONTRACT

### 5.1 Provider Interface

The system SHALL integrate with AI providers through this interface:

```python
class ILLMProvider(Protocol):
    async def analyze_batch(
        self,
        comments: List[str],
        language: str,
        schema: AnalysisSchema
    ) -> List[AnalysisResult]

    def estimate_cost(self, comments: List[str]) -> CostEstimate

    def get_capabilities(self) -> ProviderCapabilities

    @property
    def provider_id(self) -> str
```

### 5.2 Supported Providers

The system SHALL support:
1. OpenAI (gpt-4o-mini, gpt-4o) - Primary
2. Anthropic (claude-3-haiku, claude-3-sonnet) - Secondary
3. Google (gemini-1.5-flash) - Tertiary
4. Local (ollama, vllm) - Emergency fallback

### 5.3 Routing Strategy

The system SHALL route requests using configurable strategy:
- `cost_optimized`: Lowest cost provider
- `latency_optimized`: Fastest provider
- `quality_optimized`: Best quality provider
- `balanced`: Score-based selection
- `failover`: Chain with fallback

### 5.4 System Prompt

The system SHALL use this prompt for analysis:

```
Analyze customer feedback and return comprehensive JSON with maximum insights.

IMPORTANT: Be HONEST about uncertainty. Most comments are clear - only flag for review when genuinely uncertain.

For each comment, extract:

1. EMOTIONS (7 values, 0-1 scale):
   satisfaccion, frustracion, enojo, confianza, decepcion, confusion, anticipacion

2. CHURN & SENTIMENT:
   - churn_risk (0-1): likelihood customer will leave
   - sentiment_score (-1 to 1): overall sentiment
   - nps_category: p=promoter, a=passive, d=detractor

3. PAIN POINTS (array, max 3):
   - keyword (max 15 chars, Spanish, lowercase)
   - category: instalacion|velocidad|cobertura|precio|atencion|tecnico|facturacion|app|cancelacion|otro
   - severity (0-1)
   - is_primary (bool)
   - impact_score (0-1)

4. ACTIONABILITY:
   - urgency (0-1)
   - requires_followup (bool)
   - suggested_department

5. ROOT CAUSE: espera|calidad|precio|personal|tecnico|proceso|capacidad|null

6. CUSTOMER INTENT: queja|consulta|elogio|cancelacion|sugerencia|null

7. KEY TOPICS (max 3): velocidad|cobertura|instalacion|precio|atencion|calidad|app|contrato|facturacion|tecnico

8. MENTIONS: products, features, competitors

9. CONFIDENCE METRICS: sentiment_confidence, ambiguity_score, requires_human_review
```

### 5.5 Response Schema

```json
{
  "r": [
    {
      "e": [0.2, 0.7, 0.5, 0.1, 0.6, 0.3, 0.2],
      "c": 0.75,
      "s": -0.6,
      "n": "d",
      "p": [{"k": "lento", "c": "velocidad", "v": 0.8, "m": true, "imp": 0.7, "dr": ["afecta_retencion"]}],
      "u": 0.8,
      "f": true,
      "d": "tecnico",
      "r": "tecnico",
      "i": "queja",
      "t": ["velocidad", "servicio"],
      "m": {"pr": ["internet"], "fe": ["velocidad"], "co": []},
      "cf": {"sc": 0.85, "ab": 0.2, "hr": false, "ur": []}
    }
  ]
}
```

---

## 6. STORAGE ARCHITECTURE

### 6.1 Medallion Architecture

The system SHALL implement a medallion data architecture:

**Bronze Layer (Raw):**
- Original uploaded files
- Schema: as-uploaded
- Format: Original format preserved
- Retention: 24 hours

**Silver Layer (Normalized):**
- Cleaned and normalized data
- Schema: Standardized column names
- Format: Arrow Tables
- Retention: 7 days

**Gold Layer (Enriched):**
- Fully analyzed results
- Schema: 36-column output schema
- Format: Parquet (partitioned by date)
- Retention: Configurable (default: permanent)

### 6.2 Cache Architecture

**Hot Cache (In-Memory):**
- Storage: In-memory LRU (or Redis if available)
- TTL: Session duration
- Key: SHA256(language + normalized_comment)[:16]
- Value: Analysis result (NPS excluded)

**Cold Cache (Persistent):**
- Storage: Parquet files (sharded by hash prefix)
- TTL: Configurable (default: 7 days)
- Location: `cache/analysis/{language}/{hash[:2]}/{hash}.parquet`
- Schema version: 3.1

### 6.3 Cache Rules

The system SHALL:
1. NEVER cache NPS category (recompute from rating)
2. Check hot cache first, then cold cache
3. Warm hot cache on cold cache hit
4. Store to both caches on AI response
5. Invalidate on schema version mismatch

### 6.4 Cache Key Generation

```python
def generate_cache_key(comment: str, language: str) -> str:
    normalized = normalize_text(comment)
    content = f"{language}:{normalized}"
    return hashlib.sha256(content.encode()).hexdigest()[:16]
```

---

## 7. DELEGATION CONTRACTS

### 7.1 Principle

Every external dependency SHALL be behind an interface. Implementations are swappable without code changes.

### 7.2 LLM Provider Contract

```python
class ILLMProvider(Protocol):
    async def analyze_batch(self, comments, language, schema) -> List[AnalysisResult]
    def estimate_cost(self, comments) -> CostEstimate
    def get_capabilities(self) -> ProviderCapabilities
    @property
    def provider_id(self) -> str
```

**Implementations:** OpenAI, Anthropic, Google, Local (Ollama)

### 7.3 Export Contract

```python
class IExporter(Protocol):
    def export(self, data: pa.Table, options: ExportOptions) -> ExportResult
    def get_supported_formats(self) -> List[str]
    @property
    def exporter_id(self) -> str
```

**Implementations:** Arrow (Parquet, IPC, CSV), Google Sheets, OneDrive

### 7.4 Tunnel Contract

```python
class ITunnel(Protocol):
    async def connect(self) -> TunnelConnection
    async def disconnect(self) -> None
    def get_public_url(self) -> str
    def get_health(self) -> TunnelHealth
    @property
    def tunnel_id(self) -> str
```

**Implementations:** Cloudflare, Tailscale, WireGuard, Ngrok

### 7.5 Cache Contract

```python
class ICache(Protocol):
    async def get(self, key: str) -> Optional[bytes]
    async def set(self, key: str, value: bytes, ttl: int) -> None
    async def get_many(self, keys: List[str]) -> Dict[str, bytes]
    async def set_many(self, items: Dict[str, bytes], ttl: int) -> None
```

**Implementations:** In-memory LRU, Redis, Valkey, DragonflyDB

### 7.6 Compute Contract

```python
class IComputeOrchestrator(Protocol):
    async def submit_batch(self, func, items, batch_size) -> List[Future]
    async def gather_results(self, futures) -> List[Any]
    def get_cluster_status(self) -> ClusterStatus
    def scale(self, workers: int) -> None
```

**Implementations:** Local (Polars + httpx/anyio), Dask, Ray (only if customer demands with risk acceptance)

### 7.7 Storage Contract

```python
class IObjectStore(Protocol):
    def read(self, uri: str) -> pa.Table
    def write(self, uri: str, data: pa.Table) -> None
    def list(self, uri: str, pattern: str) -> List[str]
    def exists(self, uri: str) -> bool
```

**Implementations:** Local filesystem, S3, GCS, Azure Blob

### 7.8 Language Pack Contract

```python
class ILanguagePack(Protocol):
    @property
    def language_code(self) -> str
    def get_sentiment_lexicon(self) -> Dict[str, float]
    def get_emotion_categories(self) -> List[str]
    def get_churn_patterns(self) -> Dict[str, List[str]]
    def get_pain_point_keywords(self) -> Dict[str, List[str]]
```

**Implementations:** Spanish (es), English (en), Portuguese (pt)

---

## 8. VALIDATION CRITERIA

### 8.1 Column-Level Validation

| Column | Type | Tolerance |
|--------|------|-----------|
| User Score | int | Exact |
| Customer Comment | string | Exact |
| Sentiment Score | float | +/- 0.1 |
| Sentiment Category | enum | Exact |
| Emotions (7) | float | +/- 0.15 |
| Churn Risk Score | float | +/- 5 |
| Churn Risk Level | enum | Exact |
| Pain Point Category | string | Synonym match |
| Is Duplicate | bool | Exact |
| Quality Flags | string | Set match |
| Review Priority | float | +/- 5 |

### 8.2 Aggregate-Level Validation

| Metric | Tolerance |
|--------|-----------|
| NPS Score | +/- 2 points |
| NPS Distribution | +/- 2% per category |
| Avg Churn Risk | +/- 0.05 |
| High Risk Count | +/- 2% of total |
| Pain Point Distribution | +/- 3% per category |
| Duplicate Detection Rate | +/- 1% |

### 8.3 Golden Dataset Tests

For each dataset in `golden-datasets/`:
1. Process with system
2. Compare output against expected values
3. Apply tolerance rules
4. Report deviations

### 8.4 Determinism Requirements

**Must be deterministic:**
- Text normalization
- Duplicate detection (exact)
- NPS category from rating
- Schema detection

**May vary within tolerance:**
- AI sentiment scores
- Emotion detection
- Pain point classification
- Churn risk calculation

---

## 9. NON-FUNCTIONAL REQUIREMENTS

### 9.1 Performance

| Metric | Requirement |
|--------|-------------|
| 10K comments processing | < 5 minutes |
| 100K comments processing | < 45 minutes |
| File upload | < 10 seconds for 100MB |
| Schema detection | < 2 seconds |
| Cache hit latency | < 5ms |
| Cache miss latency | < 100ms |

### 9.2 Scalability

The system SHALL scale automatically based on resources:

| Environment | Cores | Memory | Batch Size | Workers |
|-------------|-------|--------|------------|---------|
| Laptop | 4 | 16GB | 50 | 4 |
| Workstation | 32 | 128GB | 400 | 32 |
| Small Cluster | 100 | 500GB | 500 | 100 |
| Enterprise | 1000+ | 5TB+ | 1000 (cap) | 1000 (cap) |

### 9.3 Reliability

| Metric | Requirement |
|--------|-------------|
| Cache hit rate (repeat) | >= 40% |
| Task success rate | >= 99% |
| Failover time | < 30 seconds |
| Data durability | 99.99% |

### 9.4 Security

The system SHALL:
1. Delegate authentication to edge (Cloudflare/Tailscale)
2. Encrypt data in transit (TLS 1.3)
3. Encrypt data at rest (AES-256)
4. Never store API keys in code
5. Sanitize all user inputs
6. Rate limit API requests

### 9.5 Deployment

The system SHALL:
1. Run in Docker containers from day zero
2. Deploy to single machine or cluster with same image
3. Support air-gapped operation (with local LLM)
4. Provide health check endpoints
5. Export metrics in OpenTelemetry format

---

## 10. CONFIGURATION PARAMETERS

### 10.1 Environment Variables

**Required:**
```
LLM_API_KEY              # Primary LLM provider API key
```

**Optional:**
```
# LLM Configuration
LLM_PROVIDER=openai                    # openai|anthropic|google|local
LLM_MODEL=gpt-4o-mini                  # Model identifier
LLM_ROUTING_STRATEGY=balanced          # cost|latency|quality|balanced|failover

# Processing
BATCH_SIZE_BASE=50                     # Base batch size (auto-scaled)
MAX_CONCURRENT_WORKERS=4               # Base worker count (auto-scaled)

# Cache
CACHE_TTL_DAYS=7                       # Hot cache TTL
CACHE_PERSISTENT_ENABLED=true          # Enable cold cache
CACHE_BYPASS=false                     # Force fresh analysis

# Storage
STORAGE_SCHEME=file                    # file|s3|gs|azure
STORAGE_BASE_PATH=/data                # Base storage path

# Tunnel
TUNNEL_PROVIDER=cloudflare             # cloudflare|tailscale|wireguard
TUNNEL_TOKEN=                          # Provider-specific token

# Observability
OTEL_EXPORTER_ENDPOINT=                # OpenTelemetry endpoint
LOG_LEVEL=INFO                         # DEBUG|INFO|WARNING|ERROR
```

### 10.2 Thresholds (All Configurable)

**Sentiment:**
```
SENTIMENT_POSITIVE_MIN=7.0
SENTIMENT_NEUTRAL_MIN=4.0
```

**NPS:**
```
NPS_PROMOTER_MIN=9
NPS_PASSIVE_MIN=7
```

**Churn Risk:**
```
CHURN_CRITICAL=80
CHURN_HIGH=60
CHURN_MEDIUM=40
```

**Review Priority:**
```
PRIORITY_URGENT=80
PRIORITY_HIGH=60
PRIORITY_MEDIUM=40
```

**Schema Detection:**
```
SCHEMA_AUTO_APPROVE=0.85
SCHEMA_PRODUCTION_MIN=0.70
SCHEMA_REJECT_BELOW=0.50
```

**Duplicate Detection:**
```
DUPLICATE_EXACT_THRESHOLD=1.0
DUPLICATE_NEAR_THRESHOLD=0.95
```

---

## APPENDIX A: KEYWORD DICTIONARIES

### Pain Point Keywords (21 Categories)

See `language_packs/es/pain_points.json` for complete Spanish keyword dictionary containing 300+ keywords across all 21 categories.

### Behavioral Patterns (Regex)

See `language_packs/es/churn_patterns.json` for complete Spanish pattern dictionary including:
- Exit threat patterns (16 patterns)
- Competitor patterns (4 patterns)
- Technical failure patterns (17 patterns)
- Recurring issue patterns (15 patterns)
- Cost concern patterns (18 patterns)
- High emotion patterns (15 patterns)

---

## APPENDIX B: RESOURCE MULTIPLIER FORMULAS

The system SHALL auto-scale based on detected resources:

```python
# Discover resources
inventory = discover_resources()

# Calculate multipliers
cpu_multiplier = inventory.cpu_cores / 4
memory_multiplier = inventory.memory_gb / 16
node_multiplier = inventory.node_count / 1

# Apply to base values
effective_batch_size = min(BASE_BATCH_SIZE * memory_multiplier, 1000)
effective_workers = min(BASE_WORKERS * cpu_multiplier * node_multiplier, 1000)
effective_partitions = min(BASE_PARTITIONS * node_multiplier, 10000)
```

---

## APPENDIX C: SCHEMA VERSION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-13 | Initial 36-column schema |

**Versioning Rules:**
- MAJOR: Breaking changes (column removed/renamed)
- MINOR: New columns added (backward compatible)
- PATCH: Bug fixes (no schema change)

---

## APPENDIX D: TASK STATE MACHINE

```
PENDING -> VALIDATING -> PROCESSING -> COMPLETED
    |          |            |             |
    v          v            v             v
 CANCELLED  FAILED      FAILED        (terminal)
```

**States:**
- PENDING: Task queued, not started
- VALIDATING: Schema and file validation
- PROCESSING: AI analysis in progress
- COMPLETED: Analysis finished successfully
- FAILED: Error occurred (retriable)
- CANCELLED: User cancelled

---

**END OF BLUEPRINT**

**Document Authority:** This is the single source of truth for system requirements.
**Implementation:** Any technology stack that satisfies these specifications is valid.
**Validation:** Use golden datasets to verify implementation correctness.

---

## APPENDIX E: LLM PROVIDER CONTRACT UPDATE (2025-12-15)

### E.1 Authoritative Interface Reference

The AI Integration Contract (Section 5) is now superseded by the detailed specification in:

```
📄 LLM_PROVIDER_CONTRACT.md (Authoritative Source)
```

### E.2 Key Changes from Original Section 5

| Aspect | Original (Section 5) | Updated (LLM_PROVIDER_CONTRACT.md) |
|--------|---------------------|-----------------------------------|
| Input Type | `List[str]` | `pa.Array` (Arrow-native) |
| Default Strategy | Cloud-first (OpenAI primary) | Local-first (Ollama primary) |
| Routing | Failover chain only | Strategy-based (local_first, cost, latency, quality, failover) |
| Batch Handling | Provider-agnostic | Provider-capability-aware |
| Cost Model | Implicit | Explicit via `ProviderCapabilities` |

### E.3 Updated Provider Hierarchy

```
LOCAL PROVIDERS (Priority 1-9, Zero Cost):
├── Ollama (priority: 1, default)
├── vLLM (priority: 2, high-throughput)
├── llama.cpp (priority: 3, lightweight)
└── LM Studio (priority: 4, desktop)

CLOUD PROVIDERS (Priority 10+, Pay-per-use):
├── OpenAI (priority: 10)
├── Anthropic (priority: 11)
├── Google Gemini (priority: 12)
└── Groq/Together/Mistral (priority: 13-15)
```

### E.4 Arrow-Native Interface Update

The `ILLMProvider` interface now requires Arrow-native input:

```python
class ILLMProvider(Protocol):
    def get_capabilities(self) -> ProviderCapabilities: ...
    async def analyze_batch(self, request: AnalysisRequest) -> List[AnalysisResult]: ...
    async def health_check(self) -> bool: ...

@dataclass
class AnalysisRequest:
    comments: pa.Array          # Arrow string array (zero-copy from table)
    language: str               # ISO 639-1 code
    analysis_schema: Dict       # JSON Schema for structured output
```

### E.5 Target Stack Clarification

The "Target Stack (Unconditional Core)" in Section 0 is clarified as follows:

| Component | Role | Relationship to LLM |
|-----------|------|---------------------|
| Arrow | Data format | LLM interface uses `pa.Array` |
| Polars | DataFrame operations | Processes batches with Rayon parallelism |
| DataFusion | Query optimization | Pipeline optimization layer |
| Cloudflare Tunnel | Edge/ingress | Unrelated to LLM |
| Docker | Containerization | Contains both local LLM and app |

**LLM Routing is separate from Compute Orchestration.** The local orchestrator (Polars + httpx/anyio) handles parallel batch execution; `LLMRouter` handles provider selection. See `BLINDSPOTS.md` and `STRATEGY.md` for compute orchestration decision rationale.

### E.6 Cross-Reference

For complete interface specification, adapter implementations, routing strategies, and performance considerations, see:

- `LLM_PROVIDER_CONTRACT.md` - Authoritative LLM interface specification
- `AGNOSTIC_BLUEPRINT.md` Appendix - Updated ILLMProvider alignment
- `TRUE_AGNOSTIC_BACKEND.md` Appendix - Adapter swappability guarantees
