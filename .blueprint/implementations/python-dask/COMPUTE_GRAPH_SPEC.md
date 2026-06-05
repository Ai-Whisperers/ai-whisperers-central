# Compute Graph Specification

**Version:** 1.0.0
**Date:** 2025-12-19
**Purpose:** Define portable execution graph for orchestrator-agnostic pipeline execution
**Status:** Specification

---

## DESIGN PRINCIPLES

```
1. GRAPH IS THE ARCHITECTURE - The computational graph defines the system
2. NODES ARE STATELESS - All state flows through edges as Arrow Tables
3. EDGES ARE DATA - Data flows on edges, never stored in nodes
4. ORCHESTRATOR AGNOSTIC - Same graph runs on any IComputeOrchestrator
5. OBSERVABLE BY DEFAULT - Every node and edge emits telemetry
6. OPTIMIZABLE - Graph can be transformed without changing semantics
```

---

## 1. CORE PROTOCOLS

### 1.1 IComputeNode

```python
from typing import Protocol, List, Dict, Any, Optional
from dataclasses import dataclass
import pyarrow as pa

@dataclass(frozen=True)
class ResourceSpec:
    """Resource requirements for scheduling"""
    min_memory_mb: int = 256
    max_memory_mb: int = 4096
    cpu_cores: float = 1.0
    gpu_required: bool = False
    gpu_memory_mb: int = 0
    estimated_duration_ms: int = 1000  # For scheduling heuristics

@dataclass(frozen=True)
class SpanConfig:
    """Observability span configuration"""
    name: str
    attributes: Dict[str, str]
    include_input_schema: bool = True
    include_output_schema: bool = True
    include_row_counts: bool = True
    include_timing: bool = True

@dataclass
class NodeResult:
    """Result of node execution"""
    output: pa.Table
    metrics: Dict[str, Any]
    duration_ms: int
    success: bool
    error: Optional[str] = None


class IComputeNode(Protocol):
    """
    Single transformation in computational graph.

    Nodes are STATELESS. All data flows through transform().
    Side effects (caching, logging) happen via injected services.
    """

    @property
    def node_id(self) -> str:
        """Unique identifier within graph"""
        ...

    @property
    def node_type(self) -> str:
        """Category for grouping: 'transform', 'llm', 'export', 'validate'"""
        ...

    @property
    def input_schema(self) -> pa.Schema:
        """Expected input Arrow schema (for validation)"""
        ...

    @property
    def output_schema(self) -> pa.Schema:
        """Guaranteed output Arrow schema"""
        ...

    @property
    def dependencies(self) -> List[str]:
        """Node IDs this node depends on (input edges)"""
        ...

    def transform(self, data: pa.Table, context: "ExecutionContext") -> NodeResult:
        """
        Execute transformation.

        Args:
            data: Input Arrow Table (validated against input_schema)
            context: Execution context with services (cache, observability, etc.)

        Returns:
            NodeResult with output table and metrics

        MUST be:
        - Deterministic for same input (unless explicitly non-deterministic)
        - Side-effect free (no external mutations)
        - Schema-conformant (output matches output_schema)
        """
        ...

    def get_resource_requirements(self) -> ResourceSpec:
        """Declared resource bounds for scheduling"""
        ...

    def get_observability_config(self) -> SpanConfig:
        """Tracing configuration for this node"""
        ...

    def validate_input(self, data: pa.Table) -> List[str]:
        """
        Validate input data before transform.

        Returns:
            List of validation errors (empty if valid)
        """
        ...
```

### 1.2 IComputeGraph

```python
from typing import Iterator, Callable, Optional
from enum import Enum

class OptimizationStrategy(Enum):
    """Graph optimization strategies"""
    NONE = "none"                    # Execute as-is
    FUSION = "fusion"                # Fuse adjacent transforms
    PARALLEL = "parallel"            # Maximize parallelization
    MEMORY = "memory"                # Minimize peak memory
    LATENCY = "latency"              # Minimize end-to-end latency
    BALANCED = "balanced"            # Balance all concerns


@dataclass
class GraphEdge:
    """Edge in compute graph (data flow)"""
    from_node: str
    to_node: str
    schema: pa.Schema  # Data schema on this edge
    estimated_rows: Optional[int] = None
    estimated_bytes: Optional[int] = None


@dataclass
class GraphMetrics:
    """Metrics from graph execution"""
    total_duration_ms: int
    node_durations: Dict[str, int]
    total_rows_processed: int
    peak_memory_mb: int
    cache_hits: int
    cache_misses: int
    llm_tokens_used: int
    llm_cost_usd: float


class IComputeGraph(Protocol):
    """
    Portable execution plan - orchestrator agnostic.

    The graph defines WHAT to compute.
    The orchestrator defines HOW to compute it.
    """

    @property
    def graph_id(self) -> str:
        """Unique identifier for this graph instance"""
        ...

    @property
    def graph_version(self) -> str:
        """Semantic version for reproducibility"""
        ...

    def add_node(self, node: IComputeNode) -> str:
        """
        Add node to graph.

        Returns:
            Node ID (may be auto-generated if not set)

        Raises:
            DuplicateNodeError: If node_id already exists
        """
        ...

    def add_edge(self, from_node: str, to_node: str) -> None:
        """
        Add directed edge (data flow) between nodes.

        Raises:
            NodeNotFoundError: If either node doesn't exist
            CycleDetectedError: If edge would create cycle
            SchemaIncompatibleError: If schemas don't match
        """
        ...

    def remove_node(self, node_id: str) -> None:
        """Remove node and all connected edges"""
        ...

    def get_node(self, node_id: str) -> IComputeNode:
        """Get node by ID"""
        ...

    def get_nodes(self) -> List[IComputeNode]:
        """Get all nodes in topological order"""
        ...

    def get_edges(self) -> List[GraphEdge]:
        """Get all edges"""
        ...

    def get_entry_nodes(self) -> List[str]:
        """Nodes with no incoming edges (data sources)"""
        ...

    def get_exit_nodes(self) -> List[str]:
        """Nodes with no outgoing edges (data sinks)"""
        ...

    def get_execution_order(self) -> List[List[str]]:
        """
        Topological sort with parallelization levels.

        Returns:
            List of node ID lists. Each inner list can execute in parallel.

        Example:
            [['input'], ['normalize', 'dedupe'], ['sentiment', 'churn'], ['export']]
            - Level 0: input (sequential)
            - Level 1: normalize, dedupe (parallel)
            - Level 2: sentiment, churn (parallel)
            - Level 3: export (sequential)
        """
        ...

    def validate(self) -> List[str]:
        """
        Validate graph structure.

        Checks:
        - No cycles
        - All dependencies satisfied
        - Schema compatibility on all edges
        - Entry/exit nodes exist

        Returns:
            List of validation errors (empty if valid)
        """
        ...

    def optimize(self, strategy: OptimizationStrategy) -> "IComputeGraph":
        """
        Return optimized copy of graph.

        Optimizations:
        - FUSION: Merge adjacent nodes with compatible transforms
        - PARALLEL: Reorder for maximum parallelization
        - MEMORY: Reorder to minimize peak memory usage
        - LATENCY: Prioritize critical path

        Returns:
            New graph instance (original unchanged)
        """
        ...

    def execute(
        self,
        orchestrator: "IComputeOrchestrator",
        input_data: Dict[str, pa.Table],
        context: "ExecutionContext"
    ) -> Dict[str, pa.Table]:
        """
        Execute graph on orchestrator.

        Args:
            orchestrator: Execution backend (Ray, Dask, asyncio, etc.)
            input_data: Dict mapping entry node IDs to input tables
            context: Execution context with services

        Returns:
            Dict mapping exit node IDs to output tables
        """
        ...

    def to_substrait(self) -> bytes:
        """
        Export as Substrait plan.

        Substrait is a cross-language serialization for query plans.
        Enables execution on DataFusion, DuckDB, Velox, etc.

        Returns:
            Serialized Substrait plan bytes
        """
        ...

    @classmethod
    def from_substrait(cls, plan: bytes) -> "IComputeGraph":
        """
        Import from Substrait plan.

        Returns:
            Reconstructed graph
        """
        ...

    def to_dict(self) -> Dict[str, Any]:
        """Serialize to dictionary (for JSON/YAML storage)"""
        ...

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "IComputeGraph":
        """Deserialize from dictionary"""
        ...

    def visualize(self) -> str:
        """
        Generate visualization (Mermaid/DOT format).

        Returns:
            Mermaid diagram string
        """
        ...
```

### 1.3 ExecutionContext

```python
@dataclass
class ExecutionContext:
    """
    Execution context passed to all nodes.

    Provides access to services without tight coupling.
    Nodes request services; context provides appropriate implementation.
    """

    # Core services
    cache: "ICache"
    observability: "IObservability"
    state_store: "IStateStore"

    # Execution metadata
    graph_id: str
    execution_id: str  # Unique per execution
    batch_id: Optional[str] = None  # For batch tracking

    # Configuration
    language: str = "es"
    schema_config: Optional[Dict[str, Any]] = None

    # LLM access (injected, not created by nodes)
    llm_provider: Optional["ILLMProvider"] = None

    # Callbacks for progress/cancellation
    on_progress: Optional[Callable[[str, float], None]] = None
    is_cancelled: Optional[Callable[[], bool]] = None

    def create_child_context(self, node_id: str) -> "ExecutionContext":
        """Create child context for node execution (for span hierarchy)"""
        ...
```

---

## 2. NODE TYPES

### 2.1 Standard Node Categories

| Category | Purpose | Examples |
|----------|---------|----------|
| `source` | Data ingestion | FileReader, APIFetch |
| `transform` | Data transformation | Normalize, Deduplicate |
| `enrich` | Add computed columns | Sentiment, ChurnRisk |
| `llm` | LLM-based analysis | LLMAnalyze, LLMCorrect |
| `aggregate` | Reduce/summarize | NPS, Statistics |
| `validate` | Quality checks | SchemaValidate, QualityFlags |
| `sink` | Data output | Export, Cache |

### 2.2 Node Contract Rules

```python
# Every node MUST follow these rules:

# 1. SCHEMA DECLARATION
# Node must declare input/output schemas
class MyNode:
    @property
    def input_schema(self) -> pa.Schema:
        return pa.schema([
            pa.field("customer_comment", pa.utf8(), nullable=False),
        ])

    @property
    def output_schema(self) -> pa.Schema:
        return pa.schema([
            pa.field("customer_comment", pa.utf8(), nullable=False),
            pa.field("normalized_comment", pa.utf8(), nullable=False),
        ])

# 2. STATELESS TRANSFORM
# Node must not maintain state between calls
def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
    # WRONG: self.counter += 1
    # RIGHT: Use context.state_store for persistent state
    pass

# 3. COLUMN PRESERVATION
# Nodes must not silently drop columns (unless explicitly documented)
def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
    # Add columns, don't replace the table
    new_col = compute_something(data.column("input"))
    result = data.append_column("new_column", new_col)
    return NodeResult(output=result, ...)

# 4. ERROR PROPAGATION
# Nodes must handle errors explicitly
def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
    try:
        result = do_work(data)
        return NodeResult(output=result, success=True, ...)
    except Exception as e:
        return NodeResult(output=data, success=False, error=str(e), ...)

# 5. OBSERVABILITY
# Nodes must emit metrics
def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
    start = time.monotonic()
    result = do_work(data)
    duration = int((time.monotonic() - start) * 1000)

    return NodeResult(
        output=result,
        metrics={"rows_processed": data.num_rows},
        duration_ms=duration,
        success=True
    )
```

---

## 3. GRAPH CONSTRUCTION

### 3.1 Builder Pattern

```python
class GraphBuilder:
    """Fluent builder for compute graphs"""

    def __init__(self, graph_id: str, version: str = "1.0.0"):
        self._graph = ComputeGraph(graph_id, version)

    def add(self, node: IComputeNode) -> "GraphBuilder":
        """Add node to graph"""
        self._graph.add_node(node)
        return self

    def connect(self, from_node: str, to_node: str) -> "GraphBuilder":
        """Connect nodes with edge"""
        self._graph.add_edge(from_node, to_node)
        return self

    def chain(self, *node_ids: str) -> "GraphBuilder":
        """Connect nodes in sequence"""
        for i in range(len(node_ids) - 1):
            self._graph.add_edge(node_ids[i], node_ids[i + 1])
        return self

    def parallel(self, from_node: str, *to_nodes: str) -> "GraphBuilder":
        """Fan out from one node to multiple"""
        for to_node in to_nodes:
            self._graph.add_edge(from_node, to_node)
        return self

    def merge(self, to_node: str, *from_nodes: str) -> "GraphBuilder":
        """Fan in from multiple nodes to one"""
        for from_node in from_nodes:
            self._graph.add_edge(from_node, to_node)
        return self

    def build(self) -> IComputeGraph:
        """Validate and return graph"""
        errors = self._graph.validate()
        if errors:
            raise GraphValidationError(errors)
        return self._graph


# Usage example:
graph = (
    GraphBuilder("feedback_analysis", "1.0.0")
    .add(FileReaderNode("input"))
    .add(NormalizeNode("normalize"))
    .add(DeduplicateNode("dedupe"))
    .add(SentimentNode("sentiment"))
    .add(ChurnNode("churn"))
    .add(PainPointNode("pain_points"))
    .add(MergeColumnsNode("merge"))
    .add(ExportNode("export"))
    .chain("input", "normalize", "dedupe")
    .parallel("dedupe", "sentiment", "churn", "pain_points")
    .merge("merge", "sentiment", "churn", "pain_points")
    .connect("merge", "export")
    .build()
)
```

### 3.2 YAML Definition

```yaml
# graphs/feedback_analysis.yaml
graph:
  id: feedback_analysis
  version: "1.0.0"
  description: Standard feedback analysis pipeline

nodes:
  - id: input
    type: source.file_reader
    config:
      formats: [csv, xlsx, parquet]

  - id: normalize
    type: transform.normalize_text
    config:
      lowercase: true
      strip_whitespace: true
      unicode_normalize: NFC

  - id: dedupe
    type: transform.deduplicate
    config:
      method: hash
      threshold: 1.0

  - id: sentiment
    type: llm.sentiment_analysis
    config:
      provider: auto
      batch_size: 50

  - id: churn
    type: llm.churn_risk
    config:
      provider: auto
      batch_size: 50

  - id: pain_points
    type: enrich.pain_point_classifier
    config:
      taxonomy_version: "1.0"

  - id: merge
    type: transform.merge_columns
    config:
      strategy: append

  - id: export
    type: sink.multi_export
    config:
      formats: [parquet, csv]

edges:
  - from: input
    to: normalize
  - from: normalize
    to: dedupe
  - from: dedupe
    to: [sentiment, churn, pain_points]
  - from: [sentiment, churn, pain_points]
    to: merge
  - from: merge
    to: export
```

---

## 4. OPTIMIZATION STRATEGIES

### 4.1 Fusion Optimization

Merge adjacent stateless transforms to reduce Arrow copies:

```python
# Before fusion:
# normalize -> lowercase -> trim -> collapse_whitespace

# After fusion:
# combined_normalize (does all three in one pass)

def fuse_transforms(graph: IComputeGraph) -> IComputeGraph:
    """Fuse compatible adjacent transforms"""

    fusable_types = {"transform.normalize", "transform.filter", "transform.project"}

    for node in graph.get_nodes():
        successors = graph.get_successors(node.node_id)

        if (len(successors) == 1 and
            node.node_type in fusable_types and
            successors[0].node_type in fusable_types):

            # Create fused node
            fused = FusedNode(node, successors[0])
            graph.replace_nodes([node.node_id, successors[0].node_id], fused)

    return graph
```

### 4.2 Parallel Optimization

Reorder independent nodes for maximum parallelization:

```python
def maximize_parallelism(graph: IComputeGraph) -> IComputeGraph:
    """Reorder nodes to maximize parallel execution"""

    # Find independent node sets
    independent_sets = find_independent_nodes(graph)

    # Schedule independent sets at same level
    for level, node_set in enumerate(independent_sets):
        for node_id in node_set:
            graph.set_execution_level(node_id, level)

    return graph
```

### 4.3 Memory Optimization

Reorder to minimize peak memory usage:

```python
def minimize_memory(graph: IComputeGraph) -> IComputeGraph:
    """Reorder to minimize peak memory"""

    # Estimate memory per node
    for node in graph.get_nodes():
        node.estimated_memory = estimate_memory(node)

    # Schedule to avoid memory spikes
    # (complete branches before starting new ones)
    schedule = topological_sort_by_memory(graph)

    return graph.with_schedule(schedule)
```

---

## 5. EXECUTION MODEL

### 5.1 Execution Flow

```
1. VALIDATE
   - Check graph structure
   - Verify schema compatibility
   - Ensure all dependencies available

2. OPTIMIZE
   - Apply optimization strategy
   - Generate execution plan

3. PREPARE
   - Allocate resources
   - Warm caches
   - Initialize observability

4. EXECUTE
   - Process nodes in topological order
   - Parallelize where possible
   - Stream data between nodes (Arrow IPC)

5. FINALIZE
   - Collect metrics
   - Cleanup resources
   - Return results
```

### 5.2 Error Handling

```python
class ExecutionPolicy(Enum):
    """How to handle node failures"""
    FAIL_FAST = "fail_fast"       # Stop on first error
    CONTINUE = "continue"         # Continue with null/default values
    RETRY = "retry"               # Retry failed nodes
    SKIP = "skip"                 # Skip failed rows, continue with rest


@dataclass
class ExecutionConfig:
    """Execution configuration"""
    policy: ExecutionPolicy = ExecutionPolicy.FAIL_FAST
    max_retries: int = 3
    retry_delay_ms: int = 1000
    timeout_ms: int = 600000  # 10 minutes
    checkpoint_interval: int = 1000  # Rows between checkpoints
```

### 5.3 Checkpointing

```python
class Checkpoint:
    """Execution checkpoint for resume"""
    graph_id: str
    execution_id: str
    completed_nodes: List[str]
    pending_nodes: List[str]
    intermediate_results: Dict[str, str]  # node_id -> parquet path
    timestamp: datetime

    def save(self, path: str) -> None:
        """Save checkpoint to disk"""
        ...

    @classmethod
    def load(cls, path: str) -> "Checkpoint":
        """Load checkpoint from disk"""
        ...


def resume_from_checkpoint(
    graph: IComputeGraph,
    checkpoint: Checkpoint,
    orchestrator: "IComputeOrchestrator",
    context: ExecutionContext
) -> Dict[str, pa.Table]:
    """Resume execution from checkpoint"""

    # Load intermediate results
    intermediate = {
        node_id: pq.read_table(path)
        for node_id, path in checkpoint.intermediate_results.items()
    }

    # Execute only pending nodes
    pending_graph = graph.subgraph(checkpoint.pending_nodes)
    return pending_graph.execute(orchestrator, intermediate, context)
```

---

## 6. OBSERVABILITY

### 6.1 Span Hierarchy

```
graph_execution (root span)
├── graph_validation
├── graph_optimization
├── node_execution: input
│   ├── file_read
│   └── schema_detection
├── node_execution: normalize
│   └── text_transform
├── node_execution: sentiment (parallel)
│   ├── cache_lookup
│   ├── llm_call
│   └── cache_store
├── node_execution: churn (parallel)
│   └── ...
└── node_execution: export
    └── file_write
```

### 6.2 Metrics per Node

```python
NODE_METRICS = {
    "node.duration_ms": "histogram",
    "node.input_rows": "counter",
    "node.output_rows": "counter",
    "node.input_bytes": "counter",
    "node.output_bytes": "counter",
    "node.memory_peak_mb": "gauge",
    "node.cache_hit_rate": "gauge",
    "node.error_count": "counter",
}

EDGE_METRICS = {
    "edge.transfer_ms": "histogram",
    "edge.bytes_transferred": "counter",
    "edge.rows_transferred": "counter",
}

GRAPH_METRICS = {
    "graph.total_duration_ms": "histogram",
    "graph.parallelism_achieved": "gauge",  # Actual vs theoretical
    "graph.memory_peak_mb": "gauge",
    "graph.llm_tokens_total": "counter",
    "graph.llm_cost_usd": "counter",
}
```

### 6.3 Data Lineage

```python
@dataclass
class LineageRecord:
    """Track data lineage through graph"""
    row_id: str
    input_source: str  # Original file/API
    nodes_touched: List[str]
    transformations: List[str]  # Description of each transform
    timestamp: datetime


def track_lineage(
    graph: IComputeGraph,
    input_data: pa.Table
) -> pa.Table:
    """Add lineage tracking column to data"""

    # Add row_id if not present
    if "row_id" not in input_data.column_names:
        row_ids = pa.array(range(input_data.num_rows))
        input_data = input_data.append_column("row_id", row_ids)

    # Add lineage column (JSON)
    lineage = [json.dumps({"nodes": [], "ts": datetime.now().isoformat()})] * input_data.num_rows
    input_data = input_data.append_column("_lineage", pa.array(lineage))

    return input_data
```

---

## 7. SUBSTRAIT INTEGRATION

### 7.1 Export to Substrait

```python
def to_substrait(graph: IComputeGraph) -> bytes:
    """
    Export graph as Substrait plan.

    Substrait is a cross-language serialization for query plans.
    Enables execution on:
    - DataFusion (Rust)
    - DuckDB (C++)
    - Velox (C++)
    - Acero (Arrow C++)
    """
    import substrait

    plan = substrait.Plan()

    # Add relations for each node
    for node in graph.get_nodes():
        rel = node_to_substrait_relation(node)
        plan.relations.append(rel)

    # Add extensions for custom nodes
    for ext in get_custom_extensions(graph):
        plan.extensions.append(ext)

    return plan.SerializeToString()


def node_to_substrait_relation(node: IComputeNode) -> substrait.Rel:
    """Convert node to Substrait relation"""

    if node.node_type == "transform.project":
        return substrait.ProjectRel(...)
    elif node.node_type == "transform.filter":
        return substrait.FilterRel(...)
    elif node.node_type == "aggregate":
        return substrait.AggregateRel(...)
    else:
        # Custom extension for non-standard nodes
        return substrait.ExtensionRel(
            extension_uri=f"feedback-arrow://{node.node_type}",
            detail=node.to_dict()
        )
```

### 7.2 Import from Substrait

```python
def from_substrait(plan_bytes: bytes) -> IComputeGraph:
    """Import graph from Substrait plan"""
    import substrait

    plan = substrait.Plan()
    plan.ParseFromString(plan_bytes)

    graph = ComputeGraph()

    for rel in plan.relations:
        node = substrait_relation_to_node(rel)
        graph.add_node(node)

    # Reconstruct edges from relation inputs
    for rel in plan.relations:
        for input_rel in rel.inputs:
            graph.add_edge(input_rel.id, rel.id)

    return graph
```

---

## 8. STANDARD PIPELINE NODES

### 8.1 Node Registry

```python
# Standard nodes included with feedback-arrow

NODE_REGISTRY = {
    # Sources
    "source.file_reader": FileReaderNode,
    "source.api_fetch": APIFetchNode,

    # Transforms
    "transform.normalize_text": NormalizeTextNode,
    "transform.deduplicate": DeduplicateNode,
    "transform.filter": FilterNode,
    "transform.project": ProjectNode,
    "transform.merge_columns": MergeColumnsNode,

    # Enrichment
    "enrich.word_count": WordCountNode,
    "enrich.pain_point_classifier": PainPointClassifierNode,
    "enrich.nps_category": NPSCategoryNode,
    "enrich.quality_flags": QualityFlagsNode,

    # LLM
    "llm.sentiment_analysis": SentimentAnalysisNode,
    "llm.churn_risk": ChurnRiskNode,
    "llm.emotion_detection": EmotionDetectionNode,
    "llm.deep_insights": DeepInsightsNode,
    "llm.discrepancy_correction": DiscrepancyCorrectionNode,

    # Aggregation
    "aggregate.nps_score": NPSScoreNode,
    "aggregate.statistics": StatisticsNode,

    # Validation
    "validate.schema": SchemaValidateNode,
    "validate.quality": QualityValidateNode,

    # Sinks
    "sink.parquet": ParquetExportNode,
    "sink.csv": CSVExportNode,
    "sink.json": JSONExportNode,
    "sink.multi_export": MultiExportNode,
}


def get_node(node_type: str, config: Dict[str, Any]) -> IComputeNode:
    """Factory function to create nodes by type"""
    if node_type not in NODE_REGISTRY:
        raise UnknownNodeTypeError(node_type)

    node_class = NODE_REGISTRY[node_type]
    return node_class(**config)
```

---

## SUMMARY

```
COMPUTE GRAPH:
- IComputeNode: Stateless transformation unit
- IComputeGraph: Portable execution DAG
- ExecutionContext: Service injection container

KEY PRINCIPLES:
- Nodes are stateless (state flows on edges)
- Edges carry Arrow Tables (zero-copy where possible)
- Graph is orchestrator-agnostic
- Observable by default
- Optimizable without semantic changes

OPTIMIZATION:
- Fusion: Merge adjacent transforms
- Parallel: Maximize parallelization
- Memory: Minimize peak memory
- Latency: Prioritize critical path

EXECUTION:
- Validate -> Optimize -> Prepare -> Execute -> Finalize
- Checkpointing for resume
- Configurable error handling

INTEROPERABILITY:
- Substrait export/import
- YAML definition
- Builder pattern API
```

---

**Document Version:** 1.0.0
**Created:** 2025-12-19
**Purpose:** Foundational specification for compute graph architecture
