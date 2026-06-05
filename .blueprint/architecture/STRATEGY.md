# Architectural Sovereignty Strategy

**Purpose:** Strategies to avoid vendor lock-in and leverage computing increasingly quick and valuable
**Created:** 2025-12-14
**Philosophy:** Own the graph, rent the execution (only when genuinely useful)

---

## CORE PRINCIPLE

```
The abstraction that matters is the GRAPH, not the executor.

Cloud vendors sell "orchestration" to create dependency.
What you actually need is a computation graph that YOU own.
Execution is trivial - 50 lines of stdlib Python.
```

---

## STRATEGY 1: GRAPH-FIRST, NOT EXECUTOR-FIRST

### The Vendor Trap

Vendors want you to think in terms of THEIR abstractions:
- Ray: "Think in actors and tasks"
- Spark: "Think in RDDs and DataFrames"
- Airflow: "Think in DAGs and operators"
- Kubernetes: "Think in pods and services"

Once you adopt their mental model, you're locked in - not by code, but by cognition.

### The Sovereign Alternative

Define YOUR computation as a portable graph:

```python
# YOU own this - it's just Python dataclasses
@dataclass
class ComputeNode:
    node_id: str
    transform: Callable[[pa.Table], pa.Table]
    inputs: List[str]
    outputs: List[str]
    is_io_bound: bool  # Hint for executor

@dataclass
class ComputeGraph:
    nodes: Dict[str, ComputeNode]
    edges: List[Tuple[str, str]]

    def topological_sort(self) -> List[str]:
        """Pure algorithm - no vendor dependency."""
        ...
```

Execution becomes trivial:

```python
import polars as pl
import anyio
import httpx

def execute_graph(graph: ComputeGraph, input_df: pl.LazyFrame) -> pl.DataFrame:
    """
    Sync Python orchestration + Rust parallelism.
    No ProcessPoolExecutor, no asyncio contamination.
    """
    order = graph.topological_sort()
    results = {"ROOT": input_df}

    for node_id in order:
        node = graph.nodes[node_id]
        inputs = [results[dep] for dep in node.inputs]

        if node.is_io_bound:
            # Isolated async only for I/O (LLM calls)
            results[node_id] = anyio.run(node.transform_async, *inputs)
        else:
            # Let Polars handle parallelism (Rayon internally)
            results[node_id] = inputs[0].with_columns([
                pl.col("comment").map_elements(
                    node.transform, return_dtype=node.output_dtype
                )
            ])

    return results["SINK"].collect()  # Rust executes in parallel
```

**Why NOT ProcessPoolExecutor:**
- Pickling: Arrow/Polars objects need special serialization
- Fork vs Spawn: Different behavior on Linux/Windows/macOS
- Memory copy: Each process copies data (1GB data = 1GB per worker)
- Deadlocks: Mixing with asyncio causes silent hangs

**Why Rust parallelism (Polars/Rayon):**
- No GIL: True parallelism without Python limitations
- No pickling: Data stays in shared memory
- No platform issues: Rayon handles threads correctly everywhere
- Zero config: Auto-detects CPU cores

### When to Add Complexity

| Scenario | Solution | Vendor Needed? |
|----------|----------|----------------|
| Single machine, <10GB | asyncio + ProcessPoolExecutor | No |
| Single machine, >10GB | Polars streaming mode | No |
| Multi-machine, batch | Dask (community-governed) | Minimal |
| Multi-machine, real-time | Evaluate carefully | Maybe |
| GPU clusters | Ray (accept risk) or roll your own | Risk accepted |

---

## STRATEGY 2: DATA FORMAT AS THE INTEGRATION POINT

### The Insight

Don't integrate at the API level. Integrate at the DATA level.

```
WRONG: System A --(vendor API)--> System B
RIGHT: System A --(Arrow)--> System B
```

APIs change, get deprecated, require authentication, have rate limits.
Data formats are stable, universal, vendor-neutral.

### Arrow as Universal Interchange

```
Any System --> Arrow Table --> Any System

- Polars: pl.from_arrow() / df.to_arrow()
- DuckDB: conn.register() / .fetch_arrow_table()
- DataFusion: ctx.register_record_batches()
- Pandas: pa.Table.from_pandas() / .to_pandas()
- Spark: via Arrow IPC
- Any language: Arrow C Data Interface
```

### Parquet as Universal Storage

```
Any System --> Parquet File --> Any System

- Compressed columnar (70-90% smaller than CSV)
- Self-describing schema
- Readable by every data tool
- No vendor lock-in (Apache governed)
- Works on local disk, S3, GCS, Azure, MinIO
```

### The Pattern

```
INPUT (any format)
    |
    v
Arrow Table (in-memory contract)
    |
    v
YOUR GRAPH (vendor-neutral transforms)
    |
    v
Arrow Table (result)
    |
    v
Parquet (cold storage) + DuckDB (query interface)
```

---

## STRATEGY 3: COMPUTE WHERE DATA LIVES

### The Anti-Pattern

```
WRONG: Move data to compute (cloud upload, API calls, network transfer)
  - Slow (network bound)
  - Expensive (egress fees)
  - Insecure (data leaves your control)
  - Dependent (on network availability)
```

### The Sovereign Pattern

```
RIGHT: Move compute to data (local processing, edge deployment)
  - Fast (memory/disk bound, not network)
  - Cheap (no egress, no API fees)
  - Secure (data never leaves)
  - Independent (works offline)
```

### Implementation

```
For 50MB Excel with 150k rows:

CLOUD APPROACH:
  Upload to S3 (2-5 seconds)
  -> Trigger Lambda/Cloud Function
  -> Process in cloud VM
  -> Download results (2-5 seconds)
  -> Pay: compute + storage + egress
  -> Total: 10-30 seconds, $0.01-0.10

LOCAL APPROACH:
  Read Excel with Polars (<1 second)
  -> Process with Arrow transforms (<2 seconds)
  -> Write Parquet (<1 second)
  -> Pay: electricity
  -> Total: <4 seconds, ~$0.0001
```

### When Cloud Makes Sense

Only when vendors offer something ACTUALLY useful:

| Cloud Service | Actually Useful When |
|---------------|---------------------|
| LLM APIs (OpenAI, Anthropic) | Model training cost > $1M, you can't self-host |
| Object Storage (S3, GCS) | Multi-region durability, >10TB, compliance |
| CDN (Cloudflare) | Global distribution, DDoS protection |
| Managed Postgres | You don't want to manage backups/failover |

NOT useful for:
- "Orchestration" (use asyncio)
- "Data pipelines" (use Arrow + your graph)
- "Analytics" (use DuckDB locally)
- "Caching" (use Redis/Valkey locally)

---

## STRATEGY 4: SELF-HOSTED FIRST, CLOUD ESCAPE HATCH

### The Decision Framework

```
For every component, ask:

1. Can I run this locally?
   YES -> Self-host by default
   NO  -> Is cloud version actually better, or just more convenient?

2. If cloud version fails/changes/price-hikes:
   Can I migrate in <1 week?
   YES -> Acceptable cloud dependency
   NO  -> Unacceptable risk, find alternative

3. What's the switching cost?
   Configuration change -> Low risk
   Code refactor -> Medium risk
   Architecture change -> High risk, avoid
```

### Component-by-Component

| Component | Self-Hosted Default | Cloud Escape Hatch | Switching Cost |
|-----------|--------------------|--------------------|----------------|
| Compute | asyncio + ProcessPool | Dask Cloud, Ray (risk) | Config change |
| Storage | Local Parquet | S3/GCS/MinIO | Config change |
| Cache | Redis/Valkey/Dragonfly | ElastiCache | Config change |
| Database | DuckDB/Postgres | RDS/Cloud SQL | Config change |
| LLM | Ollama (if quality sufficient) | OpenAI/Anthropic | Config change |
| Tunnel | Caddy/Nginx | Cloudflare | Config change |
| Observability | Prometheus + Grafana | Datadog | Config change |

**Key:** Every cloud service behind an interface. Switching = config change, not code change.

---

## STRATEGY 5: LEVERAGE INCREASING HARDWARE CAPABILITY

### The Trend

```
2015: 16GB RAM was "a lot"
2020: 64GB RAM common in workstations
2025: 128GB RAM affordable, NVMe ubiquitous
2030: 256GB+ RAM, CXL memory pooling

Your "big data" today fits in RAM tomorrow.
```

### Implications

1. **Don't over-engineer for scale you don't have**
   - 150k rows = ~50MB = fits in L3 cache of modern CPU
   - "Distributed processing" for this size is theatre

2. **Vertical scaling beats horizontal for most workloads**
   - One 128GB machine > cluster of 8x16GB machines
   - No network overhead, no coordination, no failure modes

3. **Invest in efficient algorithms, not infrastructure**
   - O(n) algorithm on single machine beats O(n log n) on cluster
   - Polars processes 1GB CSV in <2 seconds on laptop

4. **Plan for hardware to get cheaper**
   - Today's "impossible local" is tomorrow's "why would I pay cloud?"
   - Design for single-machine, add distribution only when forced

### The Hardware Leverage Stack

```
LAYER 1: Memory Efficiency (Arrow)
  - Columnar layout = cache-friendly
  - Zero-copy = no serialization tax
  - Dictionary encoding = automatic compression

LAYER 2: CPU Efficiency (Rust-based tools)
  - Polars: Rust, no GIL, SIMD vectorization
  - DataFusion: Rust, query optimization
  - DuckDB: C++, columnar execution

LAYER 3: Storage Efficiency (Parquet)
  - Columnar = read only needed columns
  - Compression = 70-90% smaller
  - Predicate pushdown = skip irrelevant data

LAYER 4: I/O Efficiency (Modern NVMe)
  - 7GB/s read on consumer NVMe
  - Your 50MB file loads in 7ms
  - "Disk is slow" is outdated thinking
```

---

## STRATEGY 6: OWN THE CRITICAL PATH, RENT THE PERIPHERY

### Classification

```
CRITICAL PATH (own completely):
  - Data format (Arrow)
  - Business logic (your algorithms)
  - Computation graph (your definition)
  - Core transforms (sentiment, churn, etc.)

PERIPHERY (rent if convenient):
  - LLM inference (until local models match quality)
  - Edge network (Cloudflare for DDoS/CDN)
  - Backup storage (S3 for disaster recovery)
```

### The Test

For each component, ask: "If this vendor disappears tomorrow, does my business stop?"

- Arrow disappears -> Won't happen (Apache Foundation, universal adoption)
- OpenAI disappears -> Switch to Anthropic/Ollama (config change)
- Cloudflare disappears -> Switch to Tailscale/Caddy (config change)
- Redis disappears -> Switch to Valkey/Dragonfly (config change)

If answer is "yes, business stops, can't switch quickly" -> You've identified unacceptable risk.

---

## STRATEGY 7: COMPLEXITY BUDGET

### The Principle

Every architectural decision has a complexity cost. You have a finite budget.

```
COMPLEXITY BUDGET: 100 points

Distributed orchestration (Ray/Dask cluster): 30 points
Kubernetes deployment: 25 points
Microservices architecture: 20 points
Event sourcing: 15 points
CQRS: 10 points
GraphQL: 10 points

vs.

Single container + asyncio: 5 points
Monolith with clear modules: 5 points
REST API: 3 points
Parquet files: 2 points
```

### For Your Use Case

```
BUDGET: 100 points

MUST HAVE:
  - Arrow data format: 5 points
  - Compute graph abstraction: 10 points
  - LLM integration: 15 points
  - Export formats: 5 points
  - Basic observability: 5 points

SUBTOTAL: 40 points

REMAINING: 60 points for future needs

DON'T SPEND ON:
  - Distributed orchestration (not needed for 150k rows)
  - Kubernetes (Docker Compose sufficient)
  - Microservices (monolith with modules sufficient)
  - Event sourcing (batch processing sufficient)
```

---

## STRATEGY 8: TIME-BOUND VENDOR DECISIONS

### The Pattern

Never make permanent vendor decisions. All vendor choices have expiration dates.

```
DECISION: Use OpenAI for LLM inference
EXPIRATION: Re-evaluate in 6 months
TRIGGER: Local models reach 90% quality at 10% cost
ACTION: Switch to Ollama/vLLM

DECISION: Use Cloudflare for tunnel
EXPIRATION: Re-evaluate in 12 months
TRIGGER: Pricing change >20% or feature regression
ACTION: Switch to Tailscale or self-hosted WireGuard

DECISION: Avoid Ray, use asyncio
EXPIRATION: Re-evaluate when workload exceeds single machine
TRIGGER: Processing time >10 minutes or data >50GB
ACTION: Evaluate Dask first, Ray only if Dask insufficient
```

### Calendar Reminder

```
Every 6 months:
  1. Review vendor dependencies
  2. Check for pricing changes
  3. Check for open-source alternatives
  4. Test switching cost (can still do it in <1 week?)
  5. Update STRATEGY.md with findings
```

---

## ANTI-STRATEGIES (What NOT To Do)

### Anti-Strategy 1: "Best of Breed" Everything

```
WRONG: Use the "best" tool for each job
  - Kafka for messaging (overkill)
  - Elasticsearch for search (overkill)
  - Redis for cache (maybe)
  - Postgres for relational (maybe)
  - MongoDB for documents (why?)
  - Ray for compute (overkill)

RESULT: 10 technologies to maintain, integrate, upgrade, secure

RIGHT: Minimal viable stack
  - DuckDB for everything queryable
  - Parquet for everything storable
  - Redis for everything cacheable
  - asyncio for everything computable

RESULT: 4 technologies, all mature, all simple
```

### Anti-Strategy 2: "Future-Proof" Over-Engineering

```
WRONG: "We might need to process 100M rows someday"
  -> Build distributed system now
  -> Spend 6 months on infrastructure
  -> Process 150k rows with cluster designed for 100M

RIGHT: "We process 150k rows today"
  -> Build for 150k (takes 1 week)
  -> Document what changes if we hit 10M
  -> Cross that bridge when we reach it
  -> Maybe hardware is 10x faster by then anyway
```

### Anti-Strategy 3: Vendor Certification as Architecture

```
WRONG: "Our team has Ray/Spark/K8s certifications"
  -> Architecture driven by what team knows
  -> Vendor lock-in through skills

RIGHT: "Our team understands distributed systems principles"
  -> Architecture driven by problem requirements
  -> Skills transfer across implementations
```

### Anti-Strategy 4: Python Multiprocessing as "Portable"

```
WRONG: "asyncio + ProcessPoolExecutor is stdlib, therefore portable"
  - Pickling hell: Not all objects serialize (Arrow, Polars, closures)
  - Fork vs Spawn: Linux forks (fast but unsafe), Windows spawns (slow but safe)
  - Memory copying: Each process gets full copy of data
  - Event loop hell: Nesting asyncio breaks, Windows has different loop
  - Silent failures: Deadlocks, exception swallowing, zombie processes

RIGHT: "Let Rust handle parallelism, Python handles orchestration"
  - Polars uses Rayon: True threading, no GIL, no pickle
  - DataFusion uses Tokio: Async without Python event loop
  - httpx + anyio: Isolated async only for I/O (LLM calls)
  - Python stays synchronous: Simple, debuggable, portable
```

---

## IMPLEMENTATION CHECKLIST

### Phase 1: Foundation (Week 1)

- [ ] Define Arrow schemas for all data contracts
- [ ] Implement ComputeGraph and ComputeNode dataclasses
- [ ] Build simple executor (asyncio + ProcessPoolExecutor)
- [ ] Set up Parquet storage layer
- [ ] Integrate DuckDB for querying

### Phase 2: Business Logic (Week 2-3)

- [ ] Implement each algorithm as a ComputeNode
- [ ] Wire nodes into analysis graph
- [ ] Add validation at node boundaries
- [ ] Implement caching layer

### Phase 3: Integration (Week 4)

- [ ] Add LLM provider interface
- [ ] Implement export formats
- [ ] Set up basic observability
- [ ] Deploy in nucleic container

### Phase 4: Hardening (Ongoing)

- [ ] Add comprehensive tests
- [ ] Document switching procedures for each vendor
- [ ] Set up 6-month vendor review calendar
- [ ] Monitor for better alternatives

---

## SUMMARY

```
1. GRAPH-FIRST: Own the computation graph, execution is trivial
2. DATA-FORMAT: Integrate at Arrow level, not API level
3. COMPUTE-TO-DATA: Process locally, avoid network/cloud tax
4. SELF-HOSTED-FIRST: Cloud only when genuinely useful
5. HARDWARE-LEVERAGE: Vertical scaling, efficient algorithms
6. OWN-CRITICAL-PATH: Business logic yours, periphery rentable
7. COMPLEXITY-BUDGET: Spend wisely, most features don't need infra
8. TIME-BOUND: All vendor decisions have expiration dates

The goal is not to avoid vendors entirely.
The goal is to never be TRAPPED by a vendor.

Trap = "If they change, we're stuck"
Freedom = "If they change, we switch (config change, not rewrite)"
```

---

**Document Status:** Strategic guidance for architectural decisions
**Review Cycle:** Every 6 months
**Next Review:** 2025-06-14
