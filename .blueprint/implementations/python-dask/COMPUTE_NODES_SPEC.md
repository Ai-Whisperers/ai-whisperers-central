# Compute Nodes Specification

**Version:** 1.0.0
**Date:** 2025-12-19
**Purpose:** Define each analysis algorithm as an IComputeNode implementation
**Derived From:** TECHNICAL_SPEC_STACK_AGNOSTIC.md
**Status:** Specification

---

## OVERVIEW

This document restructures the domain algorithms from TECHNICAL_SPEC_STACK_AGNOSTIC.md as discrete IComputeNode implementations. Each node is stateless, declares explicit input/output schemas, and can be composed into compute graphs.

---

## 1. SOURCE NODES

### 1.1 FileReaderNode

**Purpose:** Load file and convert to Arrow Table

```python
class FileReaderNode(IComputeNode):
    node_id = "file_reader"
    node_type = "source"

    @property
    def input_schema(self) -> pa.Schema:
        return None  # Source node

    @property
    def output_schema(self) -> pa.Schema:
        return pa.schema([
            pa.field("customer_comment", pa.utf8(), nullable=False),
            pa.field("user_score", pa.float64(), nullable=True),
            # Additional columns preserved from input
        ])

    def transform(self, data: None, context: ExecutionContext) -> NodeResult:
        input_path = context.config["input_path"]
        format = self._detect_format(input_path)

        if format == "csv":
            table = self._read_csv(input_path)
        elif format == "xlsx":
            table = self._read_excel(input_path)
        elif format == "parquet":
            table = pq.read_table(input_path)

        table = self._normalize_column_names(table)

        return NodeResult(
            output=table,
            metrics={"rows": table.num_rows, "format": format},
            success=True
        )

    def _detect_format(self, path: str) -> str:
        ext = Path(path).suffix.lower()
        return {".csv": "csv", ".tsv": "csv", ".xlsx": "xlsx",
                ".xls": "xlsx", ".parquet": "parquet"}[ext]

    def _read_csv(self, path: str) -> pa.Table:
        """Read CSV with encoding fallback chain"""
        encodings = ["utf-8", "utf-8-sig", "latin-1", "iso-8859-1", "cp1252"]
        for encoding in encodings:
            try:
                return pcsv.read_csv(path, parse_options=pcsv.ParseOptions(
                    encoding=encoding))
            except:
                continue
        raise EncodingError(f"Could not decode: {path}")

    def get_resource_requirements(self) -> ResourceSpec:
        return ResourceSpec(min_memory_mb=256, max_memory_mb=4096)
```

---

## 2. TRANSFORM NODES

### 2.1 NormalizeTextNode

**Purpose:** Canonical text normalization for consistent analysis

**Algorithm:**
1. Apply Unicode NFC normalization
2. Convert to lowercase
3. Strip leading/trailing whitespace
4. Collapse multiple spaces to single space

```python
class NormalizeTextNode(IComputeNode):
    node_id = "normalize_text"
    node_type = "transform"

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

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        comments = data.column("customer_comment").to_pylist()

        normalized = []
        for comment in comments:
            if comment is None:
                normalized.append("")
            else:
                text = unicodedata.normalize("NFC", str(comment))
                text = text.lower()
                text = text.strip()
                text = " ".join(text.split())
                normalized.append(text)

        result = data.append_column("normalized_comment", pa.array(normalized))

        return NodeResult(
            output=result,
            metrics={"rows_normalized": len(normalized)},
            success=True
        )

    def get_resource_requirements(self) -> ResourceSpec:
        return ResourceSpec(min_memory_mb=128, estimated_duration_ms=10)
```

### 2.2 DeduplicateNode

**Purpose:** Identify exact and near-duplicate comments

**Algorithm (Exact):**
1. Normalize comment → canonical form
2. Calculate SHA256 hash (first 16 chars)
3. Group by hash
4. Count occurrences per hash

**Algorithm (Near-Duplicate, optional):**
1. O(n²) pairwise comparison with SequenceMatcher
2. Threshold: 0.95 similarity

```python
class DeduplicateNode(IComputeNode):
    node_id = "deduplicate"
    node_type = "transform"

    SIMILARITY_THRESHOLD = 0.95

    @property
    def input_schema(self) -> pa.Schema:
        return pa.schema([
            pa.field("normalized_comment", pa.utf8(), nullable=False),
        ])

    @property
    def output_schema(self) -> pa.Schema:
        return pa.schema([
            pa.field("normalized_comment", pa.utf8(), nullable=False),
            pa.field("is_duplicate", pa.bool_(), nullable=False),
            pa.field("duplicate_count", pa.int64(), nullable=False),
            pa.field("duplicate_group_id", pa.int64(), nullable=False),
            pa.field("is_first_occurrence", pa.bool_(), nullable=False),
            pa.field("_comment_hash", pa.utf8(), nullable=False),
        ])

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        comments = data.column("normalized_comment").to_pylist()

        # Build hash map
        hash_to_first_idx = {}
        hash_to_count = {}

        is_duplicate = []
        duplicate_count = []
        duplicate_group_id = []
        is_first_occurrence = []
        comment_hashes = []

        for i, comment in enumerate(comments):
            content_hash = hashlib.sha256(comment.encode()).hexdigest()[:16]
            comment_hashes.append(content_hash)

            if content_hash in hash_to_first_idx:
                is_duplicate.append(True)
                is_first_occurrence.append(False)
                duplicate_group_id.append(hash_to_first_idx[content_hash])
                hash_to_count[content_hash] += 1
            else:
                is_duplicate.append(False)
                is_first_occurrence.append(True)
                duplicate_group_id.append(i)
                hash_to_first_idx[content_hash] = i
                hash_to_count[content_hash] = 1

        # Fill duplicate counts
        for h in comment_hashes:
            duplicate_count.append(hash_to_count[h])

        result = data
        result = result.append_column("is_duplicate", pa.array(is_duplicate))
        result = result.append_column("duplicate_count", pa.array(duplicate_count))
        result = result.append_column("duplicate_group_id", pa.array(duplicate_group_id))
        result = result.append_column("is_first_occurrence", pa.array(is_first_occurrence))
        result = result.append_column("_comment_hash", pa.array(comment_hashes))

        return NodeResult(
            output=result,
            metrics={
                "total_rows": len(comments),
                "unique_comments": len(hash_to_first_idx),
                "duplicates_found": sum(is_duplicate)
            },
            success=True
        )
```

### 2.3 WordCountNode

**Purpose:** Calculate text metrics for quality assessment

**Thresholds:**
- very_short: 1-2 words
- short: 3-5 words
- medium: 6-20 words
- long: 21-50 words
- min_for_analysis: 3 words

```python
class WordCountNode(IComputeNode):
    node_id = "word_count"
    node_type = "transform"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("word_count", pa.int64())
        ).append(
            pa.field("character_count", pa.int64())
        ).append(
            pa.field("text_length_category", pa.utf8())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        comments = data.column("normalized_comment").to_pylist()

        word_counts = []
        char_counts = []
        categories = []

        for comment in comments:
            words = comment.split() if comment else []
            wc = len(words)
            word_counts.append(wc)
            char_counts.append(len(comment) if comment else 0)
            categories.append(self._categorize(wc))

        result = data
        result = result.append_column("word_count", pa.array(word_counts))
        result = result.append_column("character_count", pa.array(char_counts))
        result = result.append_column("text_length_category", pa.array(categories))

        return NodeResult(output=result, success=True)

    def _categorize(self, word_count: int) -> str:
        if word_count <= 2:
            return "very_short"
        elif word_count <= 5:
            return "short"
        elif word_count <= 20:
            return "medium"
        else:
            return "long"
```

---

## 3. ENRICH NODES

### 3.1 LocalSentimentNode

**Purpose:** Spanish lexicon-based sentiment scoring (pre-LLM)

**Algorithm:**
1. Tokenize comment (word-level)
2. Lookup each word in Spanish lexicon
3. Apply modifiers (negation, intensifiers, sarcasm, etc.)
4. Aggregate → normalize to 0-10 scale

**Adjustments:**
- Sarcasm penalty: -15%
- Negation flip: -50% of base score
- Intensifier boost: +15%
- Conditional reduction: -10%
- Temporal complaint penalty: -20%

```python
class LocalSentimentNode(IComputeNode):
    node_id = "local_sentiment"
    node_type = "enrich"

    POSITIVE_MIN = 7.0
    NEUTRAL_MIN = 4.0

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("local_sentiment_score", pa.float64())
        ).append(
            pa.field("local_sentiment_category", pa.utf8())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        language_pack = context.get_language_pack()
        lexicon = language_pack.get_sentiment_lexicon()
        modifiers = language_pack.get_modifiers()

        comments = data.column("normalized_comment").to_pylist()
        scores = []
        categories = []

        for comment in comments:
            score = self._calculate_score(comment, lexicon, modifiers)
            scores.append(score)
            categories.append(self._categorize(score))

        result = data
        result = result.append_column("local_sentiment_score", pa.array(scores))
        result = result.append_column("local_sentiment_category", pa.array(categories))

        return NodeResult(output=result, success=True)

    def _calculate_score(
        self,
        comment: str,
        lexicon: Dict[str, float],
        modifiers: Dict
    ) -> float:
        words = comment.split()
        word_scores = []
        negation_active = False

        for word in words:
            # Check negation words
            if word in modifiers.get("negation_words", []):
                negation_active = True
                continue

            if word in lexicon:
                score = lexicon[word]

                # Apply negation
                if negation_active:
                    score = 5.0 + (5.0 - score) * 0.5  # Flip toward neutral
                    negation_active = False

                word_scores.append(score)

        if not word_scores:
            return 5.0  # Neutral default

        base_score = sum(word_scores) / len(word_scores)

        # Apply modifiers
        if self._has_sarcasm_markers(comment, modifiers):
            base_score = base_score * 0.85

        return max(0.0, min(10.0, base_score))

    def _categorize(self, score: float) -> str:
        if score >= self.POSITIVE_MIN:
            return "positive"
        elif score >= self.NEUTRAL_MIN:
            return "neutral"
        else:
            return "negative"
```

### 3.2 NPSCategoryNode

**Purpose:** Calculate NPS category from user score

**Thresholds:**
- Promoter: 9-10
- Passive: 7-8
- Detractor: 0-6

```python
class NPSCategoryNode(IComputeNode):
    node_id = "nps_category"
    node_type = "enrich"

    PROMOTER_MIN = 9
    PASSIVE_MIN = 7

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("nps_category", pa.utf8())
        ).append(
            pa.field("user_score_normalized", pa.float64())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        scores = data.column("user_score").to_pylist()

        categories = []
        normalized = []

        for score in scores:
            if score is None:
                categories.append(None)
                normalized.append(None)
            else:
                norm_score = self._normalize_score(score)
                normalized.append(norm_score)

                if norm_score >= self.PROMOTER_MIN:
                    categories.append("Promoter")
                elif norm_score >= self.PASSIVE_MIN:
                    categories.append("Passive")
                else:
                    categories.append("Detractor")

        result = data
        result = result.append_column("nps_category", pa.array(categories))
        result = result.append_column("user_score_normalized", pa.array(normalized))

        return NodeResult(output=result, success=True)

    def _normalize_score(self, score: float) -> float:
        """Normalize various scales to 0-10"""
        if 0 <= score <= 10:
            return float(score)
        elif 0 <= score <= 5:
            return score * 2
        elif 0 <= score <= 100:
            return score / 10
        else:
            return float(score)
```

### 3.3 PainPointClassifierNode

**Purpose:** Classify comments into 21 pain point categories

**Categories:**
- Core Service (6): connectivity, speed, reliability, coverage, latency, equipment
- Customer Experience (8): satisfaction, support_quality, general_quality, response_time, installation, communication, attitude
- Billing & Admin (4): billing, pricing, payment, contract
- Business Risk (3): churn_intent, competitive_pressure, trust

```python
class PainPointClassifierNode(IComputeNode):
    node_id = "pain_point_classifier"
    node_type = "enrich"

    MIN_SCORE_THRESHOLD = 2

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
        keywords = language_pack.get_pain_point_keywords()

        comments = data.column("normalized_comment").to_pylist()

        primary = []
        secondary = []
        keywords_found = []

        for comment in comments:
            matches = self._classify(comment, keywords)

            if matches:
                primary.append(matches[0]["category"])
                secondary.append(matches[1]["category"] if len(matches) > 1 else None)
                all_keywords = []
                for m in matches[:2]:
                    all_keywords.extend(m["keywords"])
                keywords_found.append(list(set(all_keywords)))
            else:
                primary.append("other")
                secondary.append(None)
                keywords_found.append([])

        result = data
        result = result.append_column("pain_point_primary", pa.array(primary))
        result = result.append_column("pain_point_secondary", pa.array(secondary))
        result = result.append_column("pain_point_keywords", pa.array(keywords_found))

        return NodeResult(output=result, success=True)

    def _classify(
        self,
        comment: str,
        keywords: Dict[str, List[str]]
    ) -> List[Dict]:
        """Classify comment into categories based on keyword matches"""
        scores = {}

        for category, words in keywords.items():
            matched = []
            for word in words:
                pattern = rf'\b{re.escape(word)}\b'
                if re.search(pattern, comment, re.IGNORECASE):
                    matched.append(word)

            if matched:
                scores[category] = {
                    "category": category,
                    "score": len(matched),
                    "keywords": matched
                }

        # Apply priority rules
        if "pricing" in scores and "billing" in scores:
            scores["pricing"]["score"] *= 2

        # Sort by score and filter
        ranked = sorted(
            scores.values(),
            key=lambda x: x["score"],
            reverse=True
        )

        return [m for m in ranked if m["score"] >= self.MIN_SCORE_THRESHOLD]
```

### 3.4 BehavioralFlagsNode

**Purpose:** Detect behavioral signals from text

**Flags:**
- Exit threat: "cancelar", "dar de baja", etc.
- Competitor mention: "tigo", "claro", etc.
- Technical failure: "sin servicio", "no funciona", etc.
- Recurring issue: "todos los dias", "siempre", etc.
- Cost concern: "caro", "costoso", etc.

```python
class BehavioralFlagsNode(IComputeNode):
    node_id = "behavioral_flags"
    node_type = "enrich"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("has_exit_threat", pa.bool_())
        ).append(
            pa.field("has_competitor_mention", pa.bool_())
        ).append(
            pa.field("has_technical_failure", pa.bool_())
        ).append(
            pa.field("has_recurring_issue", pa.bool_())
        ).append(
            pa.field("has_cost_concern", pa.bool_())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        language_pack = context.get_language_pack()
        patterns = language_pack.get_churn_patterns()

        comments = data.column("normalized_comment").to_pylist()

        flags = {
            "exit_threat": [],
            "competitor_mention": [],
            "technical_failure": [],
            "recurring_issue": [],
            "cost_concern": []
        }

        for comment in comments:
            flags["exit_threat"].append(
                self._matches_any(comment, patterns.get("exit_threat", []))
            )
            flags["competitor_mention"].append(
                self._matches_any(comment, patterns.get("competitors", []))
            )
            flags["technical_failure"].append(
                self._matches_any(comment, patterns.get("technical_failure", []))
            )
            flags["recurring_issue"].append(
                self._matches_any(comment, patterns.get("recurring_issue", []))
            )
            flags["cost_concern"].append(
                self._matches_any(comment, patterns.get("cost_concern", []))
            )

        result = data
        result = result.append_column("has_exit_threat", pa.array(flags["exit_threat"]))
        result = result.append_column("has_competitor_mention", pa.array(flags["competitor_mention"]))
        result = result.append_column("has_technical_failure", pa.array(flags["technical_failure"]))
        result = result.append_column("has_recurring_issue", pa.array(flags["recurring_issue"]))
        result = result.append_column("has_cost_concern", pa.array(flags["cost_concern"]))

        return NodeResult(output=result, success=True)

    def _matches_any(self, comment: str, patterns: List[str]) -> bool:
        for pattern in patterns:
            if re.search(rf'\b{re.escape(pattern)}\b', comment, re.IGNORECASE):
                return True
        return False
```

---

## 4. LLM NODES

> **Provider Abstraction:** All LLM nodes receive their provider via `context.llm_provider`, which implements `ILLMProvider`. Nodes are **provider-agnostic**—the same node code works with Ollama, vLLM, OpenAI, or Anthropic. Provider selection, routing strategy (local-first, cost-optimized, failover), and health-based switching are handled by `LLMRouter` at the orchestration layer, not within nodes. See `LLM_PROVIDER_CONTRACT.md` for the complete interface specification.

### 4.1 LLMSentimentNode

**Purpose:** LLM-based sentiment analysis

**Output:** Sentiment score (0-10), category, confidence

```python
class LLMSentimentNode(IComputeNode):
    node_id = "llm_sentiment"
    node_type = "llm"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("ai_sentiment_score", pa.float64())
        ).append(
            pa.field("ai_sentiment_category", pa.utf8())
        ).append(
            pa.field("sentiment_confidence", pa.float64())
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        # Filter to non-duplicates only
        mask = pc.invert(data.column("is_duplicate"))
        non_dup_data = data.filter(mask)

        if non_dup_data.num_rows == 0:
            return self._propagate_from_originals(data, context)

        # Batch LLM analysis
        request = AnalysisRequest(
            comments=non_dup_data.column("normalized_comment"),
            language=context.language,
            analysis_schema=SENTIMENT_SCHEMA
        )

        provider = context.llm_provider
        results = await provider.analyze_batch(request)

        # Build result arrays
        scores = self._build_full_array(data, non_dup_data, results, "sentiment_score")
        categories = self._build_full_array(data, non_dup_data, results, "sentiment_category")
        confidences = self._build_full_array(data, non_dup_data, results, "confidence")

        result = data
        result = result.append_column("ai_sentiment_score", pa.array(scores))
        result = result.append_column("ai_sentiment_category", pa.array(categories))
        result = result.append_column("sentiment_confidence", pa.array(confidences))

        return NodeResult(
            output=result,
            metrics={
                "llm_calls": 1,
                "comments_analyzed": non_dup_data.num_rows,
                "tokens_used": sum(r.tokens_used for r in results)
            },
            success=True
        )

    def get_resource_requirements(self) -> ResourceSpec:
        return ResourceSpec(
            min_memory_mb=256,
            estimated_duration_ms=30000
        )
```

### 4.2 LLMChurnRiskNode

**Purpose:** LLM-based churn risk detection

**Output:**
- Churn score (0-100)
- Risk level (low/medium/high/critical)
- Churn signals list
- Urgency level
- Recommendation

**Scoring Components:**
- Base score from user rating: (10 - score) × 10
- Exit threat: +30 points
- Competitor mention: +15 points
- Technical failure: +15 points
- Recurring issue: +10 points
- Cost concern: +10 points

**Special Rules:**
- Already churned (past tense): min 95
- Imminent cancellation: min 90
- High score + exit threat: min 85
- Triple threat (exit + competitor + cost): min 90

```python
class LLMChurnRiskNode(IComputeNode):
    node_id = "llm_churn_risk"
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

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        # Combine behavioral flags with LLM analysis
        request = AnalysisRequest(
            comments=data.column("normalized_comment"),
            language=context.language,
            analysis_schema=CHURN_SCHEMA
        )

        provider = context.llm_provider
        llm_results = await provider.analyze_batch(request)

        # Calculate final scores
        scores = []
        levels = []
        signals = []
        urgencies = []
        recommendations = []

        for i, row in enumerate(data.to_pylist()):
            score = self._calculate_score(row, llm_results[i])
            level = self._get_level(score)
            row_signals = self._get_signals(row)

            scores.append(score)
            levels.append(level)
            signals.append(row_signals)
            urgencies.append(self._get_urgency(row, llm_results[i]))
            recommendations.append(self._get_recommendation(level, row_signals))

        result = data
        result = result.append_column("churn_risk_score", pa.array(scores))
        result = result.append_column("churn_risk_level", pa.array(levels))
        result = result.append_column("churn_signals", pa.array(signals))
        result = result.append_column("churn_urgency", pa.array(urgencies))
        result = result.append_column("churn_recommendation", pa.array(recommendations))

        return NodeResult(output=result, success=True)

    def _calculate_score(self, row: Dict, llm_result: AnalysisResult) -> int:
        # Base score from user rating
        user_score = row.get("user_score")
        base = int((10 - (user_score or 5)) * 10)

        # Add behavioral signals
        if row.get("has_exit_threat"):
            base += 30
        if row.get("has_competitor_mention"):
            base += 15
        if row.get("has_technical_failure"):
            base += 15
        if row.get("has_recurring_issue"):
            base += 10
        if row.get("has_cost_concern"):
            base += 10

        # Apply special rules
        if self._is_already_churned(llm_result):
            base = max(base, 95)
        if self._is_imminent(llm_result):
            base = max(base, 90)
        if row.get("has_exit_threat") and row.get("has_competitor_mention") and row.get("has_cost_concern"):
            base = max(base, 90)

        return min(100, max(0, base))

    def _get_level(self, score: int) -> str:
        if score >= 80:
            return "critical"
        elif score >= 60:
            return "high"
        elif score >= 40:
            return "medium"
        else:
            return "low"
```

### 4.3 LLMEmotionNode

**Purpose:** LLM-based emotion detection (7 categories)

**Categories:**
- Positive: satisfaction, trust, anticipation
- Negative: frustration, anger, disappointment
- Neutral: confusion

```python
class LLMEmotionNode(IComputeNode):
    node_id = "llm_emotion"
    node_type = "llm"

    EMOTIONS = [
        "satisfaction", "trust", "anticipation",
        "frustration", "anger", "disappointment", "confusion"
    ]

    @property
    def output_schema(self) -> pa.Schema:
        schema = self.input_schema
        schema = schema.append(pa.field("emotion_primary", pa.utf8()))
        for emotion in self.EMOTIONS:
            schema = schema.append(pa.field(f"emotion_{emotion}", pa.float64()))
        return schema

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        request = AnalysisRequest(
            comments=data.column("normalized_comment"),
            language=context.language,
            analysis_schema=EMOTION_SCHEMA
        )

        provider = context.llm_provider
        results = await provider.analyze_batch(request)

        # Extract emotion scores
        primary = []
        emotion_scores = {e: [] for e in self.EMOTIONS}

        for result in results:
            emotions = result.raw_response.get("emotions", {})
            max_emotion = max(emotions.items(), key=lambda x: x[1], default=("neutral", 0))
            primary.append(max_emotion[0])

            for emotion in self.EMOTIONS:
                emotion_scores[emotion].append(emotions.get(emotion, 0.0))

        result = data.append_column("emotion_primary", pa.array(primary))
        for emotion in self.EMOTIONS:
            result = result.append_column(
                f"emotion_{emotion}",
                pa.array(emotion_scores[emotion])
            )

        return NodeResult(output=result, success=True)
```

### 4.4 LLMDiscrepancyNode

**Purpose:** Resolve sentiment/NPS discrepancies via LLM re-analysis

**Trigger:** abs(user_score - ai_sentiment) >= 5.0

**Output:** Corrected score, explanation, confidence, detected patterns

```python
class LLMDiscrepancyNode(IComputeNode):
    node_id = "llm_discrepancy"
    node_type = "llm"

    DISCREPANCY_THRESHOLD = 5.0

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("ai_sentiment_corrected", pa.float64())
        ).append(
            pa.field("discrepancy_detected", pa.bool_())
        ).append(
            pa.field("discrepancy_explanation", pa.utf8())
        ).append(
            pa.field("detected_patterns", pa.list_(pa.utf8()))
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        discrepancies = self._find_discrepancies(data)

        if not any(discrepancies):
            # No discrepancies - pass through
            return self._no_discrepancy_result(data)

        # LLM re-analysis for discrepant rows
        discrepant_indices = [i for i, d in enumerate(discrepancies) if d]
        discrepant_comments = [
            data.column("normalized_comment")[i].as_py()
            for i in discrepant_indices
        ]

        request = AnalysisRequest(
            comments=pa.array(discrepant_comments),
            language=context.language,
            analysis_schema=DISCREPANCY_SCHEMA
        )

        provider = context.llm_provider
        results = await provider.analyze_batch(request)

        # Build output arrays
        corrected = data.column("ai_sentiment_score").to_pylist()
        explanations = [None] * data.num_rows
        patterns = [None] * data.num_rows

        for idx, result in zip(discrepant_indices, results):
            corrected[idx] = result.raw_response.get("corrected_score")
            explanations[idx] = result.raw_response.get("explanation")
            patterns[idx] = result.raw_response.get("patterns", [])

        result = data
        result = result.append_column("ai_sentiment_corrected", pa.array(corrected))
        result = result.append_column("discrepancy_detected", pa.array(discrepancies))
        result = result.append_column("discrepancy_explanation", pa.array(explanations))
        result = result.append_column("detected_patterns", pa.array(patterns))

        return NodeResult(
            output=result,
            metrics={"discrepancies_corrected": len(discrepant_indices)},
            success=True
        )

    def _find_discrepancies(self, data: pa.Table) -> List[bool]:
        user_scores = data.column("user_score").to_pylist()
        ai_scores = data.column("ai_sentiment_score").to_pylist()

        discrepancies = []
        for user, ai in zip(user_scores, ai_scores):
            if user is None or ai is None:
                discrepancies.append(False)
            elif abs(user - ai) >= self.DISCREPANCY_THRESHOLD:
                discrepancies.append(True)
            else:
                discrepancies.append(False)

        return discrepancies
```

---

## 5. AGGREGATE NODES

### 5.1 ReviewPriorityNode

**Purpose:** Calculate 0-100 priority score for triage

**Scoring:**
- User rating contribution (0-40 points)
- Churn risk contribution (0-30 points)
- Exit threat contribution (0-20 points)
- Actionability contribution (0-10 points)

```python
class ReviewPriorityNode(IComputeNode):
    node_id = "review_priority"
    node_type = "aggregate"

    @property
    def output_schema(self) -> pa.Schema:
        return self.input_schema.append(
            pa.field("review_priority", pa.int64())
        ).append(
            pa.field("priority_level", pa.utf8())
        ).append(
            pa.field("priority_factors", pa.list_(pa.utf8()))
        )

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        priorities = []
        levels = []
        factors_list = []

        for row in data.to_pylist():
            priority = 0
            factors = []

            # User rating (0-40)
            user_score = row.get("user_score_normalized") or row.get("user_score")
            if user_score is not None:
                if user_score <= 3:
                    priority += 40
                    factors.append("low_rating")
                elif user_score <= 5:
                    priority += 30
                    factors.append("medium_rating")
                elif user_score <= 7:
                    priority += 20

            # Churn risk (0-30)
            churn = row.get("churn_risk_score", 0)
            if churn >= 80:
                priority += 30
                factors.append("critical_churn")
            elif churn >= 60:
                priority += 20
                factors.append("high_churn")
            elif churn >= 40:
                priority += 10

            # Exit threat (0-20)
            if row.get("has_exit_threat"):
                priority += 20
                factors.append("exit_threat")

            # Actionability (0-10)
            # ... calculation

            priority = min(100, max(0, priority))
            priorities.append(priority)
            levels.append(self._get_level(priority))
            factors_list.append(factors)

        result = data
        result = result.append_column("review_priority", pa.array(priorities))
        result = result.append_column("priority_level", pa.array(levels))
        result = result.append_column("priority_factors", pa.array(factors_list))

        return NodeResult(output=result, success=True)

    def _get_level(self, priority: int) -> str:
        if priority >= 80:
            return "urgent"
        elif priority >= 60:
            return "high"
        elif priority >= 40:
            return "medium"
        else:
            return "low"
```

---

## 6. SINK NODES

### 6.1 ParquetExportNode

```python
class ParquetExportNode(IComputeNode):
    node_id = "parquet_export"
    node_type = "sink"

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        output_path = context.config["output_path"]

        pq.write_table(
            data,
            output_path,
            compression="zstd",
            compression_level=3
        )

        return NodeResult(
            output=data,
            metrics={
                "rows_exported": data.num_rows,
                "file_size_bytes": Path(output_path).stat().st_size
            },
            success=True
        )
```

### 6.2 CSVExportNode

```python
class CSVExportNode(IComputeNode):
    node_id = "csv_export"
    node_type = "sink"

    def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        output_path = context.config["output_path"]

        pcsv.write_csv(data, output_path)

        return NodeResult(
            output=data,
            metrics={"rows_exported": data.num_rows},
            success=True
        )
```

---

## 7. NODE REGISTRY

```python
NODE_REGISTRY = {
    # Source
    "source.file_reader": FileReaderNode,

    # Transform
    "transform.normalize_text": NormalizeTextNode,
    "transform.deduplicate": DeduplicateNode,
    "transform.word_count": WordCountNode,

    # Enrich
    "enrich.local_sentiment": LocalSentimentNode,
    "enrich.nps_category": NPSCategoryNode,
    "enrich.pain_point_classifier": PainPointClassifierNode,
    "enrich.behavioral_flags": BehavioralFlagsNode,
    "enrich.review_priority": ReviewPriorityNode,

    # LLM
    "llm.sentiment": LLMSentimentNode,
    "llm.churn_risk": LLMChurnRiskNode,
    "llm.emotion": LLMEmotionNode,
    "llm.discrepancy": LLMDiscrepancyNode,

    # Sink
    "sink.parquet": ParquetExportNode,
    "sink.csv": CSVExportNode,
}
```

---

## SUMMARY

Each algorithm from TECHNICAL_SPEC_STACK_AGNOSTIC.md is now expressed as a discrete IComputeNode:

| Original Feature | Node Type | Node ID |
|------------------|-----------|---------|
| File Loading | source | file_reader |
| Text Normalization | transform | normalize_text |
| Duplicate Detection | transform | deduplicate |
| Word Count | transform | word_count |
| Local Sentiment (Lexicon) | enrich | local_sentiment |
| NPS Category | enrich | nps_category |
| Pain Point Classification | enrich | pain_point_classifier |
| Behavioral Flags | enrich | behavioral_flags |
| AI Sentiment | llm | llm_sentiment |
| Churn Risk | llm | llm_churn_risk |
| Emotion Detection | llm | llm_emotion |
| Discrepancy Correction | llm | llm_discrepancy |
| Review Priority | aggregate | review_priority |
| Parquet Export | sink | parquet_export |
| CSV Export | sink | csv_export |

---

## Cross-References

| Topic | Authoritative Document |
|-------|------------------------|
| IComputeNode interface | `COMPUTE_GRAPH_SPEC.md` |
| ILLMProvider interface | `LLM_PROVIDER_CONTRACT.md` |
| Provider routing/failover | `LLM_PROVIDER_CONTRACT.md` Section 3 |
| Pipeline DAG definition | `PIPELINE_DEFINITION.md` |
| State management | `STATE_STORE_SPEC.md` |

---

**Document Version:** 1.0.0
**Derived From:** TECHNICAL_SPEC_STACK_AGNOSTIC.md
**Purpose:** IComputeNode implementations of all domain algorithms
