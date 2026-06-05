# Pipeline Definition

**Version:** 1.0.0
**Date:** 2025-12-19
**Purpose:** Define the standard feedback analysis pipeline as a compute graph
**Status:** Specification

---

## OVERVIEW

The feedback analysis pipeline transforms raw customer feedback into enriched, actionable data with 36 output columns. This document defines the pipeline as a directed acyclic graph (DAG) of compute nodes.

```
┌─────────┐   ┌───────────┐   ┌──────────┐   ┌─────────────────────────────┐   ┌─────────┐   ┌────────┐
│  Input  │──▶│ Normalize │──▶│ Dedupe   │──▶│ Analysis (parallel)         │──▶│  Merge  │──▶│ Export │
└─────────┘   └───────────┘   └──────────┘   │ ┌─────────┐ ┌───────────┐  │   └─────────┘   └────────┘
                                             │ │Sentiment│ │Churn Risk │  │
                                             │ └─────────┘ └───────────┘  │
                                             │ ┌─────────┐ ┌───────────┐  │
                                             │ │Pain Pts │ │  Emotions │  │
                                             │ └─────────┘ └───────────┘  │
                                             │ ┌─────────┐ ┌───────────┐  │
                                             │ │   NPS   │ │ Insights  │  │
                                             │ └─────────┘ └───────────┘  │
                                             └─────────────────────────────┘
```

---

## 1. PIPELINE GRAPH

### 1.1 Node Definitions

| Node ID | Type | Purpose | Parallel | LLM |
|---------|------|---------|----------|-----|
| `input` | source | Load file (CSV, Excel, Parquet) | No | No |
| `validate_input` | validate | Check required columns exist | No | No |
| `normalize` | transform | Text normalization, encoding fix | No | No |
| `dedupe` | transform | Identify duplicate comments | No | No |
| `pre_enrich` | enrich | Add word count, quality flags | No | No |
| `sentiment` | llm | LLM sentiment analysis (0-10) | Yes | Yes |
| `churn` | llm | LLM churn risk detection | Yes | Yes |
| `emotions` | llm | LLM emotion detection | Yes | Yes |
| `pain_points` | llm | Pain point classification | Yes | No* |
| `nps` | enrich | NPS category from user score | Yes | No |
| `insights` | llm | Deep insights extraction | Yes | Yes |
| `discrepancy` | llm | Correct NPS/sentiment mismatch | No | Yes |
| `merge` | transform | Combine all analysis columns | No | No |
| `priority` | enrich | Calculate review priority | No | No |
| `validate_output` | validate | Check 36 columns present | No | No |
| `export` | sink | Export to Parquet/CSV/JSON | No | No |

*Pain points uses lexicon-based classification by default, LLM optional

### 1.2 Edge Definitions

```yaml
# Mermaid format
graph TD
    input --> validate_input
    validate_input --> normalize
    normalize --> dedupe
    dedupe --> pre_enrich
    pre_enrich --> sentiment
    pre_enrich --> churn
    pre_enrich --> emotions
    pre_enrich --> pain_points
    pre_enrich --> nps
    pre_enrich --> insights
    sentiment --> discrepancy
    nps --> discrepancy
    discrepancy --> merge
    churn --> merge
    emotions --> merge
    pain_points --> merge
    insights --> merge
    merge --> priority
    priority --> validate_output
    validate_output --> export
```

### 1.3 Execution Levels

```
Level 0: input
Level 1: validate_input
Level 2: normalize
Level 3: dedupe
Level 4: pre_enrich
Level 5: sentiment, churn, emotions, pain_points, nps, insights (PARALLEL)
Level 6: discrepancy (waits for sentiment + nps)
Level 7: merge (waits for all analysis nodes)
Level 8: priority
Level 9: validate_output
Level 10: export
```

---

## 2. NODE SPECIFICATIONS

### 2.1 Input Node

```python
class InputNode(IComputeNode):
    """Load file and convert to Arrow Table"""

    node_id = "input"
    node_type = "source"

    @property
    def input_schema(self) -> pa.Schema:
        return None  # Source node, no input

    @property
    def output_schema(self) -> pa.Schema:
        # Minimum required columns
        return pa.schema([
            pa.field("customer_comment", pa.utf8(), nullable=False),
            pa.field("user_score", pa.float64(), nullable=True),
        ])

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        input_path = context.config["input_path"]
        file_format = detect_format(input_path)

        if file_format == "csv":
            table = pcsv.read_csv(input_path)
        elif file_format == "xlsx":
            df = pd.read_excel(input_path)
            table = pa.Table.from_pandas(df)
        elif file_format == "parquet":
            table = pq.read_table(input_path)
        else:
            raise UnsupportedFormatError(file_format)

        # Normalize column names
        table = normalize_column_names(table)

        return NodeResult(
            output=table,
            metrics={"rows": table.num_rows, "columns": table.num_columns},
            success=True
        )
```

### 2.2 Validate Input Node

```python
class ValidateInputNode(IComputeNode):
    """Validate input has required columns"""

    node_id = "validate_input"
    node_type = "validate"

    REQUIRED_COLUMNS = ["customer_comment"]
    OPTIONAL_COLUMNS = ["user_score", "customer_id", "date"]

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        errors = []

        # Check required columns
        for col in self.REQUIRED_COLUMNS:
            if col not in data.column_names:
                errors.append(f"Missing required column: {col}")

        if errors:
            return NodeResult(
                output=data,
                success=False,
                error="; ".join(errors)
            )

        # Add missing optional columns with nulls
        for col in self.OPTIONAL_COLUMNS:
            if col not in data.column_names:
                nulls = pa.nulls(data.num_rows, type=pa.utf8())
                data = data.append_column(col, nulls)

        return NodeResult(output=data, success=True)
```

### 2.3 Normalize Node

```python
class NormalizeNode(IComputeNode):
    """Text normalization and encoding fixes"""

    node_id = "normalize"
    node_type = "transform"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("normalized_comment", pa.utf8())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        comments = data.column("customer_comment").to_pylist()

        normalized = []
        for comment in comments:
            if comment is None:
                normalized.append("")
            else:
                # Normalize unicode
                text = unicodedata.normalize("NFC", str(comment))
                # Fix encoding issues
                text = ftfy.fix_text(text)
                # Strip whitespace
                text = " ".join(text.split())
                normalized.append(text)

        result = data.append_column("normalized_comment", pa.array(normalized))
        return NodeResult(output=result, success=True)
```

### 2.4 Dedupe Node

```python
class DedupeNode(IComputeNode):
    """Identify duplicate comments"""

    node_id = "dedupe"
    node_type = "transform"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("is_duplicate", pa.bool_())
        ).append(
            pa.field("duplicate_group_id", pa.int64())
        ).append(
            pa.field("duplicate_count", pa.int64())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        comments = data.column("normalized_comment").to_pylist()

        # Build hash map
        hash_to_group = {}
        group_counts = {}
        is_duplicate = []
        group_ids = []

        for i, comment in enumerate(comments):
            content_hash = hashlib.sha256(comment.encode()).hexdigest()[:16]

            if content_hash in hash_to_group:
                is_duplicate.append(True)
                group_id = hash_to_group[content_hash]
                group_ids.append(group_id)
                group_counts[group_id] += 1
            else:
                is_duplicate.append(False)
                hash_to_group[content_hash] = i
                group_ids.append(i)
                group_counts[i] = 1

        # Calculate duplicate counts
        duplicate_counts = [group_counts[gid] for gid in group_ids]

        result = data.append_column("is_duplicate", pa.array(is_duplicate))
        result = result.append_column("duplicate_group_id", pa.array(group_ids))
        result = result.append_column("duplicate_count", pa.array(duplicate_counts))

        return NodeResult(
            output=result,
            metrics={"duplicates_found": sum(is_duplicate)},
            success=True
        )
```

### 2.5 Pre-Enrich Node

```python
class PreEnrichNode(IComputeNode):
    """Add pre-LLM computed columns"""

    node_id = "pre_enrich"
    node_type = "enrich"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("word_count", pa.int64())
        ).append(
            pa.field("character_count", pa.int64())
        ).append(
            pa.field("has_numeric", pa.bool_())
        ).append(
            pa.field("has_special_chars", pa.bool_())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        comments = data.column("normalized_comment").to_pylist()

        word_counts = []
        char_counts = []
        has_numeric = []
        has_special = []

        for comment in comments:
            words = comment.split()
            word_counts.append(len(words))
            char_counts.append(len(comment))
            has_numeric.append(bool(re.search(r'\d', comment)))
            has_special.append(bool(re.search(r'[^\w\s]', comment)))

        result = data
        result = result.append_column("word_count", pa.array(word_counts))
        result = result.append_column("character_count", pa.array(char_counts))
        result = result.append_column("has_numeric", pa.array(has_numeric))
        result = result.append_column("has_special_chars", pa.array(has_special))

        return NodeResult(output=result, success=True)
```

### 2.6 Sentiment Analysis Node (LLM)

```python
class SentimentNode(IComputeNode):
    """LLM-based sentiment analysis"""

    node_id = "sentiment"
    node_type = "llm"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("ai_sentiment_score", pa.float64())
        ).append(
            pa.field("ai_sentiment_category", pa.utf8())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        # Skip duplicates
        non_dup_mask = pc.invert(data.column("is_duplicate"))
        non_dup_indices = pc.indices_nonzero(non_dup_mask).to_pylist()

        if not non_dup_indices:
            # All duplicates, copy from originals
            return self._copy_from_originals(data, context)

        # Batch LLM analysis
        comments = [data.column("normalized_comment")[i].as_py() for i in non_dup_indices]

        request = AnalysisRequest(
            comments=pa.array(comments),
            language=context.language,
            analysis_schema=SENTIMENT_SCHEMA
        )

        provider = context.llm_provider
        results = await provider.analyze_batch(request)

        # Build result arrays
        scores = [None] * data.num_rows
        categories = [None] * data.num_rows

        for idx, result in zip(non_dup_indices, results):
            scores[idx] = result.raw_response.get("sentiment_score")
            categories[idx] = self._score_to_category(scores[idx])

        # Fill duplicates from originals
        self._fill_duplicates(data, scores, categories)

        result = data.append_column("ai_sentiment_score", pa.array(scores))
        result = result.append_column("ai_sentiment_category", pa.array(categories))

        return NodeResult(
            output=result,
            metrics={
                "llm_calls": len(non_dup_indices),
                "tokens_used": sum(r.tokens_input + r.tokens_output for r in results)
            },
            success=True
        )

    def _score_to_category(self, score: float) -> str:
        if score is None:
            return "unknown"
        if score >= 7:
            return "positive"
        if score <= 3:
            return "negative"
        return "neutral"
```

### 2.7 Churn Risk Node (LLM)

```python
class ChurnNode(IComputeNode):
    """LLM-based churn risk analysis"""

    node_id = "churn"
    node_type = "llm"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("churn_risk_score", pa.int64())
        ).append(
            pa.field("churn_risk_level", pa.utf8())
        ).append(
            pa.field("churn_signals", pa.list_(pa.utf8()))
        ).append(
            pa.field("churn_urgency", pa.utf8())
        ).append(
            pa.field("churn_recommendation", pa.utf8())
        )

    # Similar implementation pattern to SentimentNode
```

### 2.8 Pain Points Node

```python
class PainPointsNode(IComputeNode):
    """Pain point classification (lexicon + optional LLM)"""

    node_id = "pain_points"
    node_type = "enrich"  # Default lexicon-based

    # 21 pain point categories
    CATEGORIES = {
        "price": ["caro", "precio", "costoso", "económico", "barato"],
        "quality": ["calidad", "defecto", "roto", "funciona mal"],
        "service": ["atención", "espera", "respuesta", "soporte"],
        "delivery": ["envío", "llegó tarde", "no llegó", "demora"],
        "billing": ["factura", "cobro", "cargo", "pago"],
        # ... 16 more categories from BLUEPRINT.md
    }

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("pain_point_primary", pa.utf8())
        ).append(
            pa.field("pain_point_secondary", pa.utf8())
        ).append(
            pa.field("pain_point_keywords", pa.list_(pa.utf8()))
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        language_pack = context.get_language_pack()
        comments = data.column("normalized_comment").to_pylist()

        primary = []
        secondary = []
        keywords = []

        for comment in comments:
            matches = self._match_categories(comment, language_pack)

            if matches:
                primary.append(matches[0][0])
                secondary.append(matches[1][0] if len(matches) > 1 else None)
                keywords.append(list(set(kw for _, kws in matches for kw in kws)))
            else:
                primary.append("other")
                secondary.append(None)
                keywords.append([])

        result = data.append_column("pain_point_primary", pa.array(primary))
        result = result.append_column("pain_point_secondary", pa.array(secondary))
        result = result.append_column("pain_point_keywords", pa.array(keywords))

        return NodeResult(output=result, success=True)
```

### 2.9 NPS Category Node

```python
class NPSNode(IComputeNode):
    """NPS category from user score"""

    node_id = "nps"
    node_type = "enrich"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("nps_category", pa.utf8())
        ).append(
            pa.field("user_score_normalized", pa.float64())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        scores = data.column("user_score").to_pylist()
        thresholds = context.get_language_pack().thresholds["nps"]

        categories = []
        normalized = []

        for score in scores:
            if score is None:
                categories.append(None)
                normalized.append(None)
            else:
                # Normalize to 0-10 if needed
                norm_score = self._normalize_score(score)
                normalized.append(norm_score)

                if norm_score >= thresholds["promoter_min"]:
                    categories.append("Promoter")
                elif norm_score >= thresholds["passive_min"]:
                    categories.append("Passive")
                else:
                    categories.append("Detractor")

        result = data.append_column("nps_category", pa.array(categories))
        result = result.append_column("user_score_normalized", pa.array(normalized))

        return NodeResult(output=result, success=True)
```

### 2.10 Discrepancy Correction Node (LLM)

```python
class DiscrepancyNode(IComputeNode):
    """Correct NPS/Sentiment discrepancies"""

    node_id = "discrepancy"
    node_type = "llm"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("ai_sentiment_corrected", pa.float64())
        ).append(
            pa.field("discrepancy_detected", pa.bool_())
        ).append(
            pa.field("discrepancy_reason", pa.utf8())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        # Detect discrepancies
        discrepancies = self._detect_discrepancies(data)

        if not any(discrepancies):
            # No discrepancies, pass through
            corrected = data.column("ai_sentiment_score").to_pylist()
            reasons = [None] * data.num_rows
        else:
            # LLM correction for discrepant rows
            discrepant_indices = [i for i, d in enumerate(discrepancies) if d]
            corrected, reasons = await self._correct_discrepancies(
                data, discrepant_indices, context
            )

        result = data.append_column("ai_sentiment_corrected", pa.array(corrected))
        result = result.append_column("discrepancy_detected", pa.array(discrepancies))
        result = result.append_column("discrepancy_reason", pa.array(reasons))

        return NodeResult(
            output=result,
            metrics={"discrepancies_found": sum(discrepancies)},
            success=True
        )

    def _detect_discrepancies(self, data: pa.Table) -> List[bool]:
        """Detect NPS/Sentiment mismatches"""
        nps_cats = data.column("nps_category").to_pylist()
        sent_cats = data.column("ai_sentiment_category").to_pylist()

        discrepancies = []
        for nps, sent in zip(nps_cats, sent_cats):
            if nps is None or sent is None:
                discrepancies.append(False)
            elif nps == "Promoter" and sent == "negative":
                discrepancies.append(True)
            elif nps == "Detractor" and sent == "positive":
                discrepancies.append(True)
            else:
                discrepancies.append(False)

        return discrepancies
```

### 2.11 Merge Node

```python
class MergeNode(IComputeNode):
    """Merge all analysis columns"""

    node_id = "merge"
    node_type = "transform"

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        # All columns should already be present from parallel analysis
        # This node ensures correct column ordering

        # Verify all expected columns exist
        expected = self._get_expected_columns()
        missing = [col for col in expected if col not in data.column_names]

        if missing:
            return NodeResult(
                output=data,
                success=False,
                error=f"Missing columns: {missing}"
            )

        # Reorder columns to standard order
        ordered_columns = [data.column(col) for col in expected if col in data.column_names]
        result = pa.table(dict(zip(expected, ordered_columns)))

        return NodeResult(output=result, success=True)
```

### 2.12 Priority Node

```python
class PriorityNode(IComputeNode):
    """Calculate review priority score"""

    node_id = "priority"
    node_type = "enrich"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("review_priority", pa.int64())
        ).append(
            pa.field("priority_factors", pa.list_(pa.utf8()))
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        # Priority factors (from BLUEPRINT.md)
        # Score 0-100, higher = more urgent

        priorities = []
        factors = []

        for row in data.to_pylist():
            score = 0
            row_factors = []

            # Churn risk contribution (0-40 points)
            if row.get("churn_risk_score", 0) >= 80:
                score += 40
                row_factors.append("critical_churn_risk")
            elif row.get("churn_risk_score", 0) >= 60:
                score += 25
                row_factors.append("high_churn_risk")

            # Sentiment contribution (0-30 points)
            sent = row.get("ai_sentiment_corrected") or row.get("ai_sentiment_score")
            if sent is not None and sent <= 3:
                score += 30
                row_factors.append("negative_sentiment")

            # NPS contribution (0-20 points)
            if row.get("nps_category") == "Detractor":
                score += 20
                row_factors.append("detractor")

            # Discrepancy contribution (0-10 points)
            if row.get("discrepancy_detected"):
                score += 10
                row_factors.append("discrepancy")

            priorities.append(min(score, 100))
            factors.append(row_factors)

        result = data.append_column("review_priority", pa.array(priorities))
        result = result.append_column("priority_factors", pa.array(factors))

        return NodeResult(output=result, success=True)
```

### 2.13 Export Node

```python
class ExportNode(IComputeNode):
    """Export to configured formats"""

    node_id = "export"
    node_type = "sink"

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        output_path = context.config["output_path"]
        formats = context.config.get("formats", ["parquet"])

        results = {}

        for fmt in formats:
            if fmt == "parquet":
                path = f"{output_path}.parquet"
                pq.write_table(data, path, compression="zstd")
                results["parquet"] = path
            elif fmt == "csv":
                path = f"{output_path}.csv"
                pcsv.write_csv(data, path)
                results["csv"] = path
            elif fmt == "json":
                path = f"{output_path}.json"
                with open(path, "w") as f:
                    for row in data.to_pylist():
                        f.write(json.dumps(row) + "\n")
                results["json"] = path

        return NodeResult(
            output=data,
            metrics={"exported_formats": list(results.keys())},
            success=True
        )
```

---

## 3. OUTPUT SCHEMA (36 COLUMNS)

```yaml
# Standard 36-column output schema

columns:
  # Input preserved (2)
  - customer_comment: utf8 (original)
  - user_score: float64 (original NPS score)

  # Normalization (2)
  - normalized_comment: utf8
  - word_count: int64

  # Duplicate detection (3)
  - is_duplicate: bool
  - duplicate_group_id: int64
  - duplicate_count: int64

  # Sentiment (3)
  - ai_sentiment_score: float64 (0-10)
  - ai_sentiment_category: utf8 (positive/neutral/negative)
  - ai_sentiment_corrected: float64 (after discrepancy correction)

  # Churn (5)
  - churn_risk_score: int64 (0-100)
  - churn_risk_level: utf8 (low/medium/high/critical)
  - churn_signals: list<utf8>
  - churn_urgency: utf8 (immediate/short_term/medium_term/null)
  - churn_recommendation: utf8

  # Emotions (8)
  - emotion_primary: utf8
  - emotion_satisfaction: float64
  - emotion_frustration: float64
  - emotion_trust: float64
  - emotion_anger: float64
  - emotion_disappointment: float64
  - emotion_anticipation: float64
  - emotion_confusion: float64

  # Pain Points (3)
  - pain_point_primary: utf8
  - pain_point_secondary: utf8
  - pain_point_keywords: list<utf8>

  # NPS (3)
  - nps_category: utf8 (Promoter/Passive/Detractor)
  - user_score_normalized: float64 (0-10 scale)
  - discrepancy_detected: bool

  # Insights (3)
  - improvement_suggestions: list<utf8>
  - keywords_extracted: list<utf8>
  - actionability_hints: utf8

  # Priority (2)
  - review_priority: int64 (0-100)
  - priority_factors: list<utf8>

  # Metadata (2)
  - processed_at: timestamp
  - pipeline_version: utf8
```

---

## 4. CHECKPOINTING

### 4.1 Checkpoint Strategy

```python
CHECKPOINT_CONFIG = {
    "enabled": True,
    "interval_rows": 1000,        # Checkpoint every N rows
    "checkpoint_after_nodes": [   # Always checkpoint after these nodes
        "dedupe",                 # After deduplication
        "sentiment",              # After expensive LLM calls
        "churn",
        "emotions",
    ],
    "checkpoint_path": "checkpoints/{execution_id}/",
    "format": "parquet",
    "compression": "zstd"
}
```

### 4.2 Checkpoint Contents

```python
@dataclass
class PipelineCheckpoint:
    """Checkpoint for pipeline resume"""
    execution_id: str
    graph_id: str
    graph_version: str
    created_at: datetime

    # Progress tracking
    completed_nodes: List[str]
    current_node: Optional[str]
    pending_nodes: List[str]

    # Data checkpoints (parquet file paths)
    node_outputs: Dict[str, str]  # node_id -> parquet path

    # Metrics accumulated so far
    metrics: Dict[str, Any]

    # For LLM nodes: which rows have been processed
    processed_indices: Dict[str, List[int]]  # node_id -> row indices

    def save(self, path: str) -> None:
        """Save checkpoint to disk"""
        manifest = {
            "execution_id": self.execution_id,
            "graph_id": self.graph_id,
            "graph_version": self.graph_version,
            "created_at": self.created_at.isoformat(),
            "completed_nodes": self.completed_nodes,
            "current_node": self.current_node,
            "pending_nodes": self.pending_nodes,
            "node_outputs": self.node_outputs,
            "metrics": self.metrics,
            "processed_indices": self.processed_indices
        }
        with open(f"{path}/manifest.json", "w") as f:
            json.dump(manifest, f)

    @classmethod
    def load(cls, path: str) -> "PipelineCheckpoint":
        """Load checkpoint from disk"""
        with open(f"{path}/manifest.json") as f:
            manifest = json.load(f)
        return cls(**manifest)
```

### 4.3 Resume Logic

```python
async def resume_pipeline(
    checkpoint: PipelineCheckpoint,
    graph: IComputeGraph,
    context: ExecutionContext
) -> pa.Table:
    """Resume pipeline from checkpoint"""

    # Load last completed node's output
    last_completed = checkpoint.completed_nodes[-1]
    last_output_path = checkpoint.node_outputs[last_completed]
    current_data = pq.read_table(last_output_path)

    # For partially completed LLM nodes, mark processed rows
    if checkpoint.current_node:
        node = graph.get_node(checkpoint.current_node)
        if node.node_type == "llm":
            context.set_processed_indices(
                checkpoint.current_node,
                checkpoint.processed_indices.get(checkpoint.current_node, [])
            )

    # Build subgraph of remaining nodes
    remaining_nodes = checkpoint.pending_nodes
    if checkpoint.current_node:
        remaining_nodes = [checkpoint.current_node] + remaining_nodes

    subgraph = graph.subgraph(remaining_nodes)

    # Execute remaining pipeline
    result = await subgraph.execute(
        orchestrator=context.orchestrator,
        input_data={remaining_nodes[0]: current_data},
        context=context
    )

    return result[graph.get_exit_nodes()[0]]
```

---

## 5. ERROR HANDLING

### 5.1 Error Policies

```python
class ErrorPolicy(Enum):
    FAIL_FAST = "fail_fast"      # Stop pipeline on first error
    CONTINUE = "continue"        # Continue with null values for failed rows
    RETRY = "retry"              # Retry failed rows N times
    QUARANTINE = "quarantine"    # Move failed rows to separate output


PIPELINE_ERROR_CONFIG = {
    "default_policy": ErrorPolicy.CONTINUE,
    "node_policies": {
        "validate_input": ErrorPolicy.FAIL_FAST,  # Can't proceed without valid input
        "sentiment": ErrorPolicy.RETRY,            # LLM failures may be transient
        "churn": ErrorPolicy.RETRY,
        "export": ErrorPolicy.FAIL_FAST,           # Export must succeed
    },
    "retry_config": {
        "max_attempts": 3,
        "backoff_factor": 2,
        "initial_delay_ms": 1000
    }
}
```

### 5.2 Row-Level Error Tracking

```python
@dataclass
class RowError:
    """Track errors for individual rows"""
    row_index: int
    node_id: str
    error_type: str
    error_message: str
    timestamp: datetime
    retries: int = 0


class ErrorTracker:
    """Track and manage row-level errors"""

    def __init__(self, policy: ErrorPolicy):
        self.policy = policy
        self.errors: List[RowError] = []
        self.quarantined_indices: Set[int] = set()

    def record_error(self, row_index: int, node_id: str, error: Exception) -> None:
        self.errors.append(RowError(
            row_index=row_index,
            node_id=node_id,
            error_type=type(error).__name__,
            error_message=str(error),
            timestamp=datetime.utcnow()
        ))

    def should_retry(self, row_index: int, node_id: str) -> bool:
        row_errors = [e for e in self.errors if e.row_index == row_index and e.node_id == node_id]
        return len(row_errors) < self.max_retries

    def quarantine_row(self, row_index: int) -> None:
        self.quarantined_indices.add(row_index)

    def get_error_summary(self) -> Dict[str, Any]:
        return {
            "total_errors": len(self.errors),
            "quarantined_rows": len(self.quarantined_indices),
            "errors_by_node": self._group_by_node(),
            "errors_by_type": self._group_by_type()
        }
```

---

## 6. PIPELINE CONFIGURATION

### 6.1 Full Pipeline Config

```yaml
# config/pipeline.yaml

pipeline:
  id: feedback_analysis
  version: "1.0.0"

  # Input configuration
  input:
    formats: [csv, xlsx, parquet]
    required_columns: [customer_comment]
    optional_columns: [user_score, customer_id, date]
    max_rows: null  # No limit
    encoding: utf-8

  # Processing configuration
  processing:
    batch_size: 50
    parallel_llm_nodes: true
    skip_duplicates: true  # Don't send duplicates to LLM

  # LLM configuration
  # Provider selection is handled by LLMRouter, not hardcoded.
  # "auto" uses local-first routing: Ollama → vLLM → OpenAI → Anthropic
  # Available strategies: local_first, cost_optimized, quality_optimized, failover
  # See LLM_PROVIDER_CONTRACT.md for routing details.
  llm:
    provider: auto  # Use router (local-first by default)
    routing_strategy: local_first
    timeout_seconds: 120
    max_retries: 3
    fallback_enabled: true  # Failover to next provider on error

  # Modules enabled
  modules:
    sentiment: true
    churn: true
    emotions: true
    pain_points: true
    nps: true
    insights: true
    discrepancy_correction: true

  # Checkpointing
  checkpoint:
    enabled: true
    interval_rows: 1000
    path: checkpoints/

  # Error handling
  errors:
    policy: continue
    max_retries: 3
    quarantine_path: quarantine/

  # Output configuration
  output:
    formats: [parquet]
    compression: zstd
    include_metadata: true
```

### 6.2 Pipeline Factory

```python
def create_default_pipeline(config: Dict[str, Any] = None) -> IComputeGraph:
    """Create standard feedback analysis pipeline"""

    config = config or load_config("config/pipeline.yaml")

    builder = GraphBuilder(
        graph_id=config["pipeline"]["id"],
        version=config["pipeline"]["version"]
    )

    # Add nodes
    builder.add(InputNode("input", config["input"]))
    builder.add(ValidateInputNode("validate_input"))
    builder.add(NormalizeNode("normalize"))
    builder.add(DedupeNode("dedupe"))
    builder.add(PreEnrichNode("pre_enrich"))

    # Add enabled analysis modules
    if config["modules"]["sentiment"]:
        builder.add(SentimentNode("sentiment", config["llm"]))
    if config["modules"]["churn"]:
        builder.add(ChurnNode("churn", config["llm"]))
    if config["modules"]["emotions"]:
        builder.add(EmotionsNode("emotions", config["llm"]))
    if config["modules"]["pain_points"]:
        builder.add(PainPointsNode("pain_points"))
    if config["modules"]["nps"]:
        builder.add(NPSNode("nps"))
    if config["modules"]["insights"]:
        builder.add(InsightsNode("insights", config["llm"]))

    if config["modules"]["discrepancy_correction"]:
        builder.add(DiscrepancyNode("discrepancy", config["llm"]))

    builder.add(MergeNode("merge"))
    builder.add(PriorityNode("priority"))
    builder.add(ValidateOutputNode("validate_output"))
    builder.add(ExportNode("export", config["output"]))

    # Connect edges
    builder.chain("input", "validate_input", "normalize", "dedupe", "pre_enrich")

    # Fan out to parallel analysis
    analysis_nodes = []
    for module in ["sentiment", "churn", "emotions", "pain_points", "nps", "insights"]:
        if config["modules"].get(module, False):
            analysis_nodes.append(module)

    builder.parallel("pre_enrich", *analysis_nodes)

    # Discrepancy needs sentiment + nps
    if config["modules"]["discrepancy_correction"]:
        builder.connect("sentiment", "discrepancy")
        builder.connect("nps", "discrepancy")
        builder.merge("merge", "discrepancy", "churn", "emotions", "pain_points", "insights")
    else:
        builder.merge("merge", *analysis_nodes)

    builder.chain("merge", "priority", "validate_output", "export")

    return builder.build()
```

---

## 10. DATA LINEAGE

### 10.1 Row Provenance Tracking

Every output row maintains a link to its source:

```python
@dataclass
class RowProvenance:
    """Tracks the origin and transformation path of each row"""
    input_row_id: str          # Original row ID from input
    output_row_id: str         # Final row ID in output
    input_hash: str            # SHA-256 of original comment
    workspace_id: str          # Tenant context
    analysis_id: str           # Job ID

    # Transformation metadata
    was_duplicate: bool        # Marked as duplicate?
    duplicate_of: Optional[str] # If duplicate, ID of original
    was_quarantined: bool      # Had processing errors?
    quarantine_reason: Optional[str]

@dataclass
class TransformationRecord:
    """Record of a single transformation"""
    node_id: str
    node_type: str
    timestamp: datetime
    duration_ms: int
    input_hash: str            # Hash of input data
    output_hash: str           # Hash of output data
    columns_added: List[str]
    columns_modified: List[str]
```

### 10.2 Node Touch Log

Track which nodes processed each row:

```python
@dataclass
class NodeTouchEntry:
    """Record that a node processed a row"""
    row_id: str
    node_id: str
    node_type: str
    timestamp: datetime
    duration_ms: int
    status: str                # "success" | "error" | "skipped"
    error_message: Optional[str]
    columns_produced: List[str]

class LineageTracker:
    """Track lineage throughout pipeline execution"""

    def __init__(self, analysis_id: str, workspace_id: str):
        self.analysis_id = analysis_id
        self.workspace_id = workspace_id
        self.touches: List[NodeTouchEntry] = []
        self.provenance: Dict[str, RowProvenance] = {}

    def record_touch(
        self,
        row_id: str,
        node_id: str,
        node_type: str,
        status: str,
        columns_produced: List[str],
        duration_ms: int,
        error: Optional[str] = None
    ) -> None:
        self.touches.append(NodeTouchEntry(
            row_id=row_id,
            node_id=node_id,
            node_type=node_type,
            timestamp=datetime.utcnow(),
            duration_ms=duration_ms,
            status=status,
            error_message=error,
            columns_produced=columns_produced
        ))

    def get_row_history(self, row_id: str) -> List[NodeTouchEntry]:
        """Get full processing history for a row"""
        return [t for t in self.touches if t.row_id == row_id]

    def get_error_rows(self) -> List[str]:
        """Get rows that had errors"""
        error_rows = set()
        for touch in self.touches:
            if touch.status == "error":
                error_rows.add(touch.row_id)
        return list(error_rows)
```

### 10.3 Lineage Storage Schema

```python
# Arrow schema for lineage storage
LINEAGE_SCHEMA = pa.schema([
    ("analysis_id", pa.string()),
    ("row_id", pa.string()),
    ("input_row_id", pa.string()),
    ("input_hash", pa.string()),
    ("node_id", pa.string()),
    ("node_type", pa.string()),
    ("timestamp", pa.timestamp("us", tz="UTC")),
    ("duration_ms", pa.int32()),
    ("status", pa.string()),
    ("error_message", pa.string()),
    ("columns_produced", pa.list_(pa.string())),
])

# Store lineage alongside results
# {workspace_id}/analyses/{analysis_id}/lineage.parquet
```

### 10.4 Lineage Export Format

**JSON-LD (W3C PROV Compatible):**
```json
{
  "@context": "https://www.w3.org/ns/prov#",
  "@type": "Bundle",
  "entity": {
    "fa:row_001": {
      "@type": "Entity",
      "prov:generatedAtTime": "2025-01-15T10:30:00Z",
      "fa:inputHash": "sha256:abc123...",
      "fa:sentiment": "positive",
      "fa:sentimentScore": 0.85
    }
  },
  "activity": {
    "fa:sentiment_node": {
      "@type": "Activity",
      "prov:startedAtTime": "2025-01-15T10:29:55Z",
      "prov:endedAtTime": "2025-01-15T10:30:00Z",
      "prov:used": "fa:row_001_input",
      "prov:generated": "fa:row_001",
      "fa:nodeType": "sentiment",
      "fa:llmProvider": "ollama"
    }
  },
  "wasGeneratedBy": {
    "fa:row_001": "fa:sentiment_node"
  }
}
```

### 10.5 Lineage Query API

```python
class LineageQueryService:
    """Query lineage data"""

    async def get_row_lineage(
        self,
        analysis_id: str,
        row_id: str
    ) -> RowLineage:
        """Get complete lineage for a single row"""
        touches = await self.persistence.find(
            "lineage",
            {"analysis_id": analysis_id, "row_id": row_id}
        )
        return RowLineage(
            row_id=row_id,
            input_hash=touches[0]["input_hash"],
            nodes_touched=[t["node_id"] for t in touches],
            timeline=[NodeTouchEntry(**t) for t in touches]
        )

    async def get_column_lineage(
        self,
        analysis_id: str,
        column_name: str
    ) -> ColumnLineage:
        """Find which node produced a column"""
        touches = await self.persistence.find(
            "lineage",
            {
                "analysis_id": analysis_id,
                "columns_produced": {"$in": [column_name]}
            }
        )
        if not touches:
            raise ColumnNotFoundError(column_name)

        return ColumnLineage(
            column_name=column_name,
            produced_by=touches[0]["node_id"],
            node_type=touches[0]["node_type"]
        )

    async def trace_error(
        self,
        analysis_id: str,
        row_id: str
    ) -> ErrorTrace:
        """Get detailed error trace for a failed row"""
        touches = await self.persistence.find(
            "lineage",
            {
                "analysis_id": analysis_id,
                "row_id": row_id,
                "status": "error"
            }
        )
        return ErrorTrace(
            row_id=row_id,
            failed_at_node=touches[-1]["node_id"] if touches else None,
            error_message=touches[-1]["error_message"] if touches else None,
            successful_nodes=[t["node_id"] for t in touches if t["status"] == "success"]
        )
```

---

## 11. EXPLAINABILITY

### 11.1 Score Contribution Breakdown

Every score should be explainable:

```python
@dataclass
class ScoreExplanation:
    """Breakdown of how a score was calculated"""
    score_name: str            # "sentiment_score", "churn_risk", etc.
    final_score: float
    contributions: List[ScoreContribution]
    confidence: float
    explanation_text: str      # Human-readable summary

@dataclass
class ScoreContribution:
    """Individual factor contributing to a score"""
    factor: str                # "keyword_match", "llm_inference", "rule_based"
    weight: float              # 0.0 - 1.0
    value: float               # Contribution amount
    evidence: str              # What triggered this contribution

# Example sentiment explanation
explanation = ScoreExplanation(
    score_name="sentiment_score",
    final_score=0.85,
    contributions=[
        ScoreContribution(
            factor="positive_keywords",
            weight=0.3,
            value=0.25,
            evidence="Found 'excellent', 'love', 'great'"
        ),
        ScoreContribution(
            factor="llm_inference",
            weight=0.5,
            value=0.45,
            evidence="LLM classified as strongly positive"
        ),
        ScoreContribution(
            factor="user_score_correlation",
            weight=0.2,
            value=0.15,
            evidence="User score 9/10 correlates with positive sentiment"
        )
    ],
    confidence=0.92,
    explanation_text="High positive sentiment driven by positive keywords and user's high rating"
)
```

### 11.2 Explanation Generation

```python
class ExplanationGenerator:
    """Generate human-readable explanations for scores"""

    TEMPLATES = {
        "sentiment": {
            "positive_high": "Strong positive sentiment ({score:.0%}) based on {factors}",
            "positive": "Positive sentiment ({score:.0%}) indicated by {factors}",
            "neutral": "Neutral sentiment ({score:.0%}) with mixed signals",
            "negative": "Negative sentiment ({score:.0%}) due to {factors}",
            "negative_high": "Strong negative sentiment ({score:.0%}) from {factors}",
        },
        "churn": {
            "high": "High churn risk ({score}%) - {factors}",
            "medium": "Moderate churn risk ({score}%) - {factors}",
            "low": "Low churn risk ({score}%) - {factors}",
        }
    }

    def generate_sentiment_explanation(
        self,
        score: float,
        contributions: List[ScoreContribution]
    ) -> str:
        """Generate explanation for sentiment score"""
        # Determine template
        if score >= 0.8:
            template_key = "positive_high"
        elif score >= 0.6:
            template_key = "positive"
        elif score >= 0.4:
            template_key = "neutral"
        elif score >= 0.2:
            template_key = "negative"
        else:
            template_key = "negative_high"

        # Format factors
        factors = self._format_contributions(contributions)

        return self.TEMPLATES["sentiment"][template_key].format(
            score=score,
            factors=factors
        )

    def _format_contributions(self, contributions: List[ScoreContribution]) -> str:
        """Format contributions as readable text"""
        top_factors = sorted(contributions, key=lambda c: c.value, reverse=True)[:3]
        return ", ".join(c.evidence for c in top_factors)
```

### 11.3 Confidence Intervals

```python
@dataclass
class ConfidenceInterval:
    """Confidence interval for a score"""
    point_estimate: float
    lower_bound: float
    upper_bound: float
    confidence_level: float    # 0.95 for 95% CI

class ConfidenceEstimator:
    """Estimate confidence for LLM outputs"""

    def estimate_llm_confidence(
        self,
        response: LLMResponse,
        prompt_type: str
    ) -> ConfidenceInterval:
        """Estimate confidence based on LLM response characteristics"""

        # Base confidence from response
        base_confidence = self._extract_llm_confidence(response)

        # Adjust for response characteristics
        adjustments = []

        # Check for hedging language
        hedging_words = ["maybe", "possibly", "uncertain", "might"]
        hedging_count = sum(
            1 for word in hedging_words
            if word in response.text.lower()
        )
        if hedging_count > 0:
            adjustments.append(-0.05 * hedging_count)

        # Check for confident language
        confident_words = ["definitely", "clearly", "certainly", "absolutely"]
        confident_count = sum(
            1 for word in confident_words
            if word in response.text.lower()
        )
        if confident_count > 0:
            adjustments.append(0.05 * confident_count)

        # Adjust based on prompt type (some are more reliable)
        prompt_reliability = {
            "sentiment": 0.0,      # Well-calibrated
            "churn": -0.05,        # More subjective
            "emotions": -0.10,    # Harder to validate
            "insights": -0.15,    # Most subjective
        }
        adjustments.append(prompt_reliability.get(prompt_type, 0))

        # Calculate final confidence
        final = base_confidence + sum(adjustments)
        final = max(0.5, min(0.99, final))  # Clamp to reasonable range

        # Calculate confidence interval
        margin = (1 - final) / 2
        return ConfidenceInterval(
            point_estimate=response.score,
            lower_bound=max(0, response.score - margin),
            upper_bound=min(1, response.score + margin),
            confidence_level=final
        )
```

### 11.4 Explanation Storage

```python
# Store explanations alongside results
EXPLANATION_SCHEMA = pa.schema([
    ("row_id", pa.string()),
    ("score_name", pa.string()),
    ("final_score", pa.float32()),
    ("confidence", pa.float32()),
    ("explanation_text", pa.string()),
    ("contributions", pa.string()),  # JSON array
    ("confidence_lower", pa.float32()),
    ("confidence_upper", pa.float32()),
])

# Enable/disable via configuration
EXPLAINABILITY_CONFIG = {
    "enabled": True,
    "store_contributions": True,
    "store_confidence_intervals": True,
    "generate_text_explanations": True,
    "max_contributions_stored": 5,
}
```

### 11.5 Explanation API

```python
# REST endpoint for explanations
# GET /api/v1/tasks/{task_id}/explain/{row_id}

@dataclass
class RowExplanation:
    """Complete explanation for a row"""
    row_id: str
    scores: Dict[str, ScoreExplanation]
    lineage: RowLineage
    confidence_summary: str

# Example response
{
    "row_id": "row_001",
    "scores": {
        "sentiment_score": {
            "final_score": 0.85,
            "confidence": 0.92,
            "confidence_interval": [0.78, 0.92],
            "explanation": "Strong positive sentiment (85%) based on positive keywords and high user rating",
            "contributions": [
                {"factor": "positive_keywords", "weight": 0.3, "value": 0.25},
                {"factor": "llm_inference", "weight": 0.5, "value": 0.45},
                {"factor": "user_score", "weight": 0.2, "value": 0.15}
            ]
        },
        "churn_risk": {
            "final_score": 15,
            "confidence": 0.88,
            "explanation": "Low churn risk (15%) - no exit intent keywords detected",
            "contributions": [
                {"factor": "no_competitor_mention", "weight": 0.4, "value": 0.0},
                {"factor": "positive_sentiment", "weight": 0.3, "value": -10},
                {"factor": "high_user_score", "weight": 0.3, "value": -5}
            ]
        }
    },
    "lineage": {
        "input_hash": "sha256:abc123...",
        "nodes_touched": ["input", "normalize", "sentiment", "churn", "merge"],
        "processing_time_ms": 1250
    },
    "confidence_summary": "High confidence analysis with 92% confidence in sentiment and 88% in churn risk"
}
```

### 11.6 Explanation Caching

```python
class ExplanationCache:
    """Cache explanations for repeated queries"""

    def __init__(self, cache: ICache, ttl_seconds: int = 86400):
        self.cache = cache
        self.ttl = ttl_seconds

    def _key(self, analysis_id: str, row_id: str) -> str:
        return f"explain:{analysis_id}:{row_id}"

    async def get(
        self,
        analysis_id: str,
        row_id: str
    ) -> Optional[RowExplanation]:
        data = await self.cache.get(self._key(analysis_id, row_id))
        if data:
            return RowExplanation.from_json(data)
        return None

    async def set(
        self,
        analysis_id: str,
        row_id: str,
        explanation: RowExplanation
    ) -> None:
        await self.cache.set(
            self._key(analysis_id, row_id),
            explanation.to_json().encode(),
            ttl=self.ttl
        )
```

---

## SUMMARY

```
PIPELINE STRUCTURE:
├── Input Phase
│   ├── input: Load file
│   ├── validate_input: Check columns
│   └── normalize: Fix encoding/whitespace
│
├── Deduplication Phase
│   ├── dedupe: Identify duplicates
│   └── pre_enrich: Add word count, flags
│
├── Analysis Phase (PARALLEL)
│   ├── sentiment: LLM sentiment (0-10)
│   ├── churn: LLM churn risk (0-100)
│   ├── emotions: LLM emotion scores
│   ├── pain_points: Category classification
│   ├── nps: NPS category from score
│   └── insights: LLM deep insights
│
├── Correction Phase
│   └── discrepancy: Fix NPS/sentiment mismatches
│
├── Aggregation Phase
│   ├── merge: Combine all columns
│   └── priority: Calculate review priority
│
└── Output Phase
    ├── validate_output: Verify 36 columns
    └── export: Write Parquet/CSV/JSON

OUTPUT: 36 columns covering sentiment, churn, emotions, pain points, NPS, insights, and priority

CHECKPOINTING: After deduplication and each LLM node
ERROR HANDLING: Per-row tracking, retry/quarantine options
```

---

## Cross-References

| Topic | Authoritative Document |
|-------|------------------------|
| IComputeGraph interface | `COMPUTE_GRAPH_SPEC.md` |
| Node implementations | `COMPUTE_NODES_SPEC.md` |
| ILLMProvider interface | `LLM_PROVIDER_CONTRACT.md` |
| Provider routing strategies | `LLM_PROVIDER_CONTRACT.md` Section 3 |
| State management | `STATE_STORE_SPEC.md` |
| Export formats | `EXPORT_CONTRACT.md` |

---

**Document Version:** 1.0.0
**Created:** 2025-12-19
**Purpose:** Define standard feedback analysis pipeline
