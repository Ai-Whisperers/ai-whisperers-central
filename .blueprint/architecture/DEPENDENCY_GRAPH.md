# Interface Dependency Graph

**Purpose:** Define interface dependencies and composition order
**Principle:** Interfaces form a directed acyclic graph - implement leaves first, then dependents

---

## 1. Interface Dependency DAG

```
Level 0 (No Dependencies - Foundation)
┌──────────────────────────────────────────────────────────────────────┐
│  ILanguagePack    IStorage    ISecretStore    IObservability         │
└──────────────────────────────────────────────────────────────────────┘
           │            │              │                │
           ▼            ▼              ▼                ▼
Level 1 (Single Dependency)
┌──────────────────────────────────────────────────────────────────────┐
│  ICache           IStateStore         ILLMProvider                   │
│  (→IStorage)      (→IStorage)         (→ISecretStore,                │
│                                         ILanguagePack)               │
└──────────────────────────────────────────────────────────────────────┘
           │            │                      │
           ▼            ▼                      ▼
Level 2 (Multi-Dependency)
┌──────────────────────────────────────────────────────────────────────┐
│  IComputeNode                                                        │
│  (→IStateStore, ICache, ILLMProvider, IObservability)               │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
Level 3 (Orchestration)
┌──────────────────────────────────────────────────────────────────────┐
│  IComputeGraph                                                       │
│  (→IComputeNode[], IStateStore, IObservability)                     │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
Level 4 (Execution)
┌──────────────────────────────────────────────────────────────────────┐
│  IComputeOrchestrator                                                │
│  (→IComputeGraph, IResourcePool, ICheckpointer)                     │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
Level 5 (External Interface)
┌──────────────────────────────────────────────────────────────────────┐
│  IExporter    ITunnel    IEventStream    IPersistence               │
│  (→IStorage)  (→IObservability)                                     │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Interface Catalog

### Level 0: Foundation (No Dependencies)

| Interface | Purpose | Implementations |
|-----------|---------|-----------------|
| `ILanguagePack` | Language-specific resources | SpanishPack, EnglishPack |
| `IStorage` | File/object storage | LocalStorage, S3Storage |
| `ISecretStore` | API key management | EnvSecretStore, VaultStore |
| `IObservability` | Metrics, traces, logs | ConsoleObserver, OTLPObserver |

### Level 1: Core Services

| Interface | Purpose | Dependencies | Implementations |
|-----------|---------|--------------|-----------------|
| `ICache` | Key-value caching | IStorage | MemoryCache, RedisCache |
| `IStateStore` | Cross-batch state | IStorage | MemoryStateStore, RedisStateStore |
| `ILLMProvider` | LLM abstraction | ISecretStore, ILanguagePack | OllamaAdapter, OpenAIAdapter |

### Level 2: Processing

| Interface | Purpose | Dependencies | Implementations |
|-----------|---------|--------------|-----------------|
| `IComputeNode` | Data transformation | IStateStore, ICache, ILLMProvider, IObservability | All analysis nodes |

### Level 3: Graph

| Interface | Purpose | Dependencies | Implementations |
|-----------|---------|--------------|-----------------|
| `IComputeGraph` | DAG orchestration | IComputeNode[], IStateStore, IObservability | AnalysisPipeline |

### Level 4: Orchestration

| Interface | Purpose | Dependencies | Implementations |
|-----------|---------|--------------|-----------------|
| `IComputeOrchestrator` | Distributed execution | IComputeGraph, IResourcePool, ICheckpointer | LocalOrchestrator, RayOrchestrator |
| `IResourcePool` | Resource discovery | IObservability | LocalResourcePool, KubernetesPool |
| `ICheckpointer` | Fault tolerance | IStorage | FileCheckpointer, S3Checkpointer |

### Level 5: External

| Interface | Purpose | Dependencies | Implementations |
|-----------|---------|--------------|-----------------|
| `IExporter` | Output generation | IStorage | ParquetExporter, CSVExporter |
| `ITunnel` | Edge connectivity | IObservability | CloudflareTunnel, TailscaleTunnel |
| `IEventStream` | Event streaming | - | RedpandaStream, NATSStream |
| `IPersistence` | Structured storage | - | DuckDBPersistence, PostgresPersistence |

---

## 3. Dependency Edges

### 3.1 Required Dependencies (MUST inject)

```python
# These dependencies MUST be provided at construction time

ICache:
  storage: IStorage              # For cold tier persistence

IStateStore:
  storage: IStorage              # For checkpoint persistence

ILLMProvider:
  secret_store: ISecretStore     # For API key access
  language_pack: ILanguagePack   # For prompt templates

IComputeNode:
  state_store: IStateStore       # For stateful operations
  cache: ICache                  # For result caching
  observer: IObservability       # For tracing

IComputeGraph:
  nodes: List[IComputeNode]      # Nodes in the graph
  state_store: IStateStore       # For graph-level state
  observer: IObservability       # For execution traces

IComputeOrchestrator:
  graph: IComputeGraph           # The graph to execute
  resource_pool: IResourcePool   # Resource discovery
  checkpointer: ICheckpointer    # For resume capability
```

### 3.2 Optional Dependencies (MAY inject)

```python
# These dependencies are optional with sensible defaults

IComputeNode:
  llm_provider: Optional[ILLMProvider]  # Only for LLM-calling nodes

IExporter:
  compressor: Optional[ICompressor]     # Default: snappy for Parquet

ICache:
  hot_tier: Optional[ICache]            # Default: in-memory LRU
```

---

## 4. Composition Patterns

### 4.1 Minimal Local Composition

```python
# Minimal dependencies for local development

def build_local_system() -> IComputeOrchestrator:
    # Level 0: Foundation
    storage = LocalStorage(base_path="/tmp/feedback-arrow")
    secrets = EnvSecretStore()
    observer = ConsoleObserver()
    lang_pack = SpanishPack()

    # Level 1: Services
    cache = MemoryCache()
    state_store = MemoryStateStore()
    llm = OllamaAdapter(
        secret_store=secrets,
        language_pack=lang_pack
    )

    # Level 2-3: Pipeline
    pipeline = build_analysis_pipeline(
        state_store=state_store,
        cache=cache,
        llm_provider=llm,
        observer=observer
    )

    # Level 4: Orchestrator
    return LocalOrchestrator(
        graph=pipeline,
        resource_pool=LocalResourcePool(),
        checkpointer=FileCheckpointer(storage)
    )
```

### 4.2 Production Composition

```python
# Full production dependencies

def build_production_system() -> IComputeOrchestrator:
    # Level 0: Foundation
    storage = S3Storage(bucket=config.S3_BUCKET)
    secrets = VaultStore(url=config.VAULT_URL)
    observer = OTLPObserver(endpoint=config.OTEL_ENDPOINT)
    lang_pack = load_language_pack(config.DEFAULT_LANGUAGE)

    # Level 1: Services
    cache = RedisCache(
        url=config.REDIS_URL,
        cold_storage=storage
    )
    state_store = RedisStateStore(url=config.REDIS_URL)

    llm = LLMRouter(
        providers=[
            OllamaAdapter(secrets, lang_pack),
            VLLMAdapter(secrets, lang_pack),
            OpenAIAdapter(secrets, lang_pack),
            AnthropicAdapter(secrets, lang_pack),
        ],
        strategy=config.LLM_ROUTING_STRATEGY
    )

    # Level 2-3: Pipeline
    pipeline = build_analysis_pipeline(
        state_store=state_store,
        cache=cache,
        llm_provider=llm,
        observer=observer
    )

    # Level 4: Orchestrator
    return RayOrchestrator(
        graph=pipeline,
        resource_pool=KubernetesPool(),
        checkpointer=S3Checkpointer(storage)
    )
```

### 4.3 Test Composition

```python
# Minimal dependencies for testing

def build_test_system() -> IComputeOrchestrator:
    # All in-memory, no external dependencies
    storage = MemoryStorage()
    secrets = DictSecretStore({"OPENAI_API_KEY": "test-key"})
    observer = NullObserver()
    lang_pack = SpanishPack()

    cache = MemoryCache()
    state_store = MemoryStateStore()
    llm = MockLLMProvider()  # Returns predictable responses

    pipeline = build_analysis_pipeline(
        state_store=state_store,
        cache=cache,
        llm_provider=llm,
        observer=observer
    )

    return LocalOrchestrator(
        graph=pipeline,
        resource_pool=LocalResourcePool(),
        checkpointer=MemoryCheckpointer()
    )
```

---

## 5. Anti-Lock-In Strategy

### 5.1 Principle

```
Vendors become:              Customers depend on:
├── Swappable commodities    ├── Our schema (v1.x.x)
├── Competing for business   ├── Our language packs
├── Unable to replace us     ├── Our export formats
└── Interchangeable backends └── Our API contracts
```

### 5.2 Interface Swappability Matrix

| Layer | Interface | Primary | Alternatives | Self-Hosted |
|-------|-----------|---------|--------------|-------------|
| LLM | ILLMProvider | Ollama | OpenAI, Anthropic | vLLM, llama.cpp |
| Export | IExporter | Parquet | CSV, JSON | Local files |
| Tunnel | ITunnel | Cloudflare | Tailscale | WireGuard |
| Compute | IComputeOrchestrator | Local | Ray | Dask |
| Cache | ICache | Memory | Redis | Valkey, DragonflyDB |
| Events | IEventStream | Redpanda | Kafka | NATS |
| Storage | IStorage | Local | S3 | MinIO |

### 5.3 Switching Verification

```python
async def verify_swappability(interface_type: Type[T], implementations: List[T]):
    """Verify all implementations are interchangeable"""

    test_data = generate_test_input(interface_type)
    results = []

    for impl in implementations:
        # Inject each implementation into the same test harness
        result = await run_standard_test(impl, test_data)
        results.append(result)

    # All implementations must produce equivalent output
    reference = results[0]
    for result in results[1:]:
        assert_outputs_equivalent(reference, result)
```

---

## 6. Resource Scaling Graph

```
Infrastructure Multiplier: Same code, auto-scaled execution

┌─────────────────────────────────────────────────────────────┐
│                    IResourcePool.discover()                 │
│                            │                                │
│    ┌───────────────────────┼───────────────────────┐       │
│    ▼                       ▼                       ▼       │
│ Laptop                Workstation              Cluster      │
│ 4 cores               32 cores                 1000 cores   │
│ 16GB RAM              128GB RAM                5TB RAM      │
│ 1 node                1 node                   100 nodes    │
│    │                       │                       │       │
│    ▼                       ▼                       ▼       │
│ batch=50              batch=400               batch=1000    │
│ workers=4             workers=32              workers=1000  │
│ partitions=10         partitions=10           partitions=1K │
└─────────────────────────────────────────────────────────────┘

Formula:
  batch_size = min(base * memory_multiplier, MAX_BATCH)
  workers = min(base * cpu_multiplier * node_count, MAX_WORKERS)
  partitions = min(base * node_count, MAX_PARTITIONS)
```

---

## 7. Implementation Order

Based on the dependency DAG, interfaces MUST be implemented in level order:

```
Order: Implement all interfaces at Level N before any at Level N+1

Level 0: ILanguagePack, IStorage, ISecretStore, IObservability
         │
         └─► All foundation interfaces must exist before Level 1

Level 1: ICache, IStateStore, ILLMProvider
         │
         └─► Can now build stateful services

Level 2: IComputeNode
         │
         └─► Can now define transformation nodes

Level 3: IComputeGraph
         │
         └─► Can now compose nodes into pipelines

Level 4: IComputeOrchestrator, IResourcePool, ICheckpointer
         │
         └─► Can now execute pipelines

Level 5: IExporter, ITunnel, IEventStream, IPersistence
         │
         └─► Can now expose to external systems
```

---

## 8. Circular Dependency Prevention

### 8.1 Forbidden Patterns

```python
# FORBIDDEN: Circular dependency
class CacheA:
    def __init__(self, cache_b: "CacheB"): ...

class CacheB:
    def __init__(self, cache_a: CacheA): ...

# FORBIDDEN: Lower level depending on higher level
class Storage:  # Level 0
    def __init__(self, graph: IComputeGraph): ...  # Level 3 - WRONG
```

### 8.2 Resolution Patterns

```python
# ALLOWED: Event-based decoupling
class CacheA:
    def __init__(self, event_bus: IEventBus):
        self.event_bus = event_bus

    def on_eviction(self, key: str):
        self.event_bus.publish("cache.evicted", key)

class CacheB:
    def __init__(self, event_bus: IEventBus):
        event_bus.subscribe("cache.evicted", self.handle_eviction)

    def handle_eviction(self, key: str):
        # React to eviction from CacheA
        ...

# ALLOWED: Callback injection
class Storage:
    def __init__(self, on_write: Optional[Callable] = None):
        self.on_write = on_write

# Injected at composition time, not construction
storage = Storage(on_write=graph.invalidate_cache)
```

---

## 9. Validation Checklist

| Check | Description | Verification |
|-------|-------------|--------------|
| No cycles | Dependency graph is acyclic | `find_cycles(graph) == []` |
| Level order | All deps at lower level than dependent | `max(dep.level) < interface.level` |
| Interface only | Dependencies are interfaces, not implementations | `all(is_protocol(dep))` |
| Swappable | Multiple implementations per interface | `len(implementations) >= 2` |
| Testable | In-memory implementation exists | `has_memory_impl(interface)` |

---

## 10. Cross-Reference

| Topic | Authoritative Document |
|-------|------------------------|
| IComputeNode/IComputeGraph | `COMPUTE_GRAPH_SPEC.md` |
| Node implementations | `COMPUTE_NODES_SPEC.md` |
| IStateStore/IPersistence | `STATE_STORE_SPEC.md` |
| Pipeline DAG definition | `PIPELINE_DEFINITION.md` |
| ILLMProvider | `LLM_PROVIDER_CONTRACT.md` |
| IExporter | `EXPORT_CONTRACT.md` |
| ILanguagePack | `LANGUAGE_PACK_SPEC.md` |
| API/CLI interface | `API_CONTRACT.md` |
| Lifecycle/operations | `OPERATIONS_SPEC.md` |

---

**Generated:** 2025-12-19
**Derived from:** TRUE_AGNOSTIC_BACKEND.md
**Focus:** Interface dependencies and composition order
