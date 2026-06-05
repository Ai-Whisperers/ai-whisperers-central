# Validation Suite Specification

**Version:** 1.0.0
**Date:** 2025-12-19
**Purpose:** Define golden datasets, expected outputs, and validation tolerances
**Status:** Specification

---

## OVERVIEW

The validation suite ensures feedback-arrow produces consistent, accurate, and reproducible results. It consists of:

1. **Golden Datasets** - Curated test data with known expected outputs
2. **Validation Rules** - Schema and business logic validation
3. **Tolerances** - Acceptable ranges for LLM-generated values
4. **Regression Tests** - Ensure changes don't break existing functionality

---

## 1. GOLDEN DATASETS

### 1.1 Dataset Structure

```
golden_datasets/
├── index.yaml                    # Dataset registry
├── spanish/
│   ├── small_100.csv            # 100 rows, quick tests
│   ├── medium_1000.csv          # 1000 rows, standard tests
│   ├── large_10000.csv          # 10k rows, scale tests
│   ├── edge_cases.csv           # Edge cases and corner cases
│   ├── duplicates.csv           # Duplicate detection tests
│   └── expected/
│       ├── small_100_expected.parquet
│       ├── medium_1000_expected.parquet
│       └── edge_cases_expected.parquet
├── english/
│   ├── small_100.csv
│   └── expected/
│       └── small_100_expected.parquet
└── schemas/
    └── expected_output.json     # JSON Schema for expected format
```

### 1.2 Dataset Registry

```yaml
# golden_datasets/index.yaml

datasets:
  spanish_small:
    path: spanish/small_100.csv
    language: es
    rows: 100
    expected: spanish/expected/small_100_expected.parquet
    purpose: Quick validation, CI/CD
    tolerance_profile: standard

  spanish_medium:
    path: spanish/medium_1000.csv
    language: es
    rows: 1000
    expected: spanish/expected/medium_1000_expected.parquet
    purpose: Standard validation
    tolerance_profile: standard

  spanish_large:
    path: spanish/large_10000.csv
    language: es
    rows: 10000
    expected: spanish/expected/large_10000_expected.parquet
    purpose: Scale testing, performance benchmarks
    tolerance_profile: relaxed

  spanish_edge_cases:
    path: spanish/edge_cases.csv
    language: es
    rows: 50
    expected: spanish/expected/edge_cases_expected.parquet
    purpose: Edge case validation
    tolerance_profile: strict

  spanish_duplicates:
    path: spanish/duplicates.csv
    language: es
    rows: 200
    expected: null  # Validated differently
    purpose: Duplicate detection validation
    tolerance_profile: exact

  english_small:
    path: english/small_100.csv
    language: en
    rows: 100
    expected: english/expected/small_100_expected.parquet
    purpose: English language validation
    tolerance_profile: standard
```

### 1.3 Input Data Format

```csv
# Example: spanish/small_100.csv

customer_comment,user_score,customer_id,date
"Excelente servicio, muy satisfecho con la atención",9,C001,2025-01-15
"Pésimo, no funciona y nadie responde",2,C002,2025-01-15
"El producto llegó tarde pero funciona bien",6,C003,2025-01-15
"Voy a cancelar, esto es inaceptable",1,C004,2025-01-15
"Muy caro pero la calidad es buena",7,C005,2025-01-15
...
```

### 1.4 Expected Output Format

```python
# Expected output schema (36 columns)

EXPECTED_SCHEMA = pa.schema([
    # Input preserved
    ("customer_comment", pa.utf8()),
    ("user_score", pa.float64()),

    # Normalization
    ("normalized_comment", pa.utf8()),
    ("word_count", pa.int64()),

    # Duplicate detection
    ("is_duplicate", pa.bool_()),
    ("duplicate_group_id", pa.int64()),
    ("duplicate_count", pa.int64()),

    # Sentiment
    ("ai_sentiment_score", pa.float64()),
    ("ai_sentiment_category", pa.utf8()),
    ("ai_sentiment_corrected", pa.float64()),

    # Churn
    ("churn_risk_score", pa.int64()),
    ("churn_risk_level", pa.utf8()),
    ("churn_signals", pa.list_(pa.utf8())),
    ("churn_urgency", pa.utf8()),
    ("churn_recommendation", pa.utf8()),

    # Emotions (8)
    ("emotion_primary", pa.utf8()),
    ("emotion_satisfaction", pa.float64()),
    ("emotion_frustration", pa.float64()),
    ("emotion_trust", pa.float64()),
    ("emotion_anger", pa.float64()),
    ("emotion_disappointment", pa.float64()),
    ("emotion_anticipation", pa.float64()),
    ("emotion_confusion", pa.float64()),

    # Pain Points
    ("pain_point_primary", pa.utf8()),
    ("pain_point_secondary", pa.utf8()),
    ("pain_point_keywords", pa.list_(pa.utf8())),

    # NPS
    ("nps_category", pa.utf8()),
    ("user_score_normalized", pa.float64()),
    ("discrepancy_detected", pa.bool_()),

    # Insights
    ("improvement_suggestions", pa.list_(pa.utf8())),
    ("keywords_extracted", pa.list_(pa.utf8())),
    ("actionability_hints", pa.utf8()),

    # Priority
    ("review_priority", pa.int64()),
    ("priority_factors", pa.list_(pa.utf8())),

    # Metadata
    ("processed_at", pa.timestamp("ms")),
    ("pipeline_version", pa.utf8()),
])
```

---

## 2. TOLERANCE PROFILES

### 2.1 Profile Definitions

```yaml
# Tolerance profiles for validation

tolerance_profiles:
  strict:
    description: "Exact or very tight tolerances"
    use_case: "Edge cases, critical business rules"
    tolerances:
      sentiment_score: 0.5      # ±0.5 points
      churn_risk_score: 5       # ±5 points
      emotion_scores: 0.1       # ±0.1
      categorical: exact         # Must match exactly
      lists: subset_match        # Expected subset of actual

  standard:
    description: "Standard tolerances for typical validation"
    use_case: "Regular testing, CI/CD"
    tolerances:
      sentiment_score: 1.0      # ±1 point
      churn_risk_score: 10      # ±10 points
      emotion_scores: 0.15      # ±0.15
      categorical: fuzzy_80     # 80% match rate required
      lists: overlap_50         # 50% overlap required

  relaxed:
    description: "Looser tolerances for scale/performance tests"
    use_case: "Large datasets, LLM variance testing"
    tolerances:
      sentiment_score: 1.5      # ±1.5 points
      churn_risk_score: 15      # ±15 points
      emotion_scores: 0.2       # ±0.2
      categorical: fuzzy_70     # 70% match rate
      lists: overlap_30         # 30% overlap

  exact:
    description: "Exact match required (deterministic fields)"
    use_case: "Duplicate detection, schema validation"
    tolerances:
      sentiment_score: 0        # Exact
      all_fields: exact         # All must match exactly
```

### 2.2 Tolerance Implementation

```python
from dataclasses import dataclass
from typing import Union, List, Any

@dataclass
class ToleranceConfig:
    """Tolerance configuration for a field"""
    field: str
    tolerance_type: str  # "numeric", "categorical", "list", "exact"
    value: Union[float, str]


class ToleranceValidator:
    """Validate values against tolerances"""

    def __init__(self, profile: str):
        self.profile = TOLERANCE_PROFILES[profile]

    def validate_numeric(
        self,
        actual: float,
        expected: float,
        field: str
    ) -> bool:
        """Validate numeric value within tolerance"""
        tolerance = self.profile["tolerances"].get(field, 1.0)
        if tolerance == 0:
            return actual == expected
        return abs(actual - expected) <= tolerance

    def validate_categorical(
        self,
        actual: str,
        expected: str,
        field: str
    ) -> bool:
        """Validate categorical value"""
        mode = self.profile["tolerances"].get("categorical", "exact")

        if mode == "exact":
            return actual == expected

        if mode.startswith("fuzzy_"):
            # Fuzzy matching with threshold
            threshold = int(mode.split("_")[1]) / 100
            return self._fuzzy_match(actual, expected) >= threshold

        return actual == expected

    def validate_list(
        self,
        actual: List[str],
        expected: List[str],
        field: str
    ) -> bool:
        """Validate list values"""
        mode = self.profile["tolerances"].get("lists", "exact")

        if mode == "exact":
            return set(actual) == set(expected)

        if mode == "subset_match":
            # Expected is subset of actual
            return set(expected).issubset(set(actual))

        if mode.startswith("overlap_"):
            # Minimum overlap percentage
            threshold = int(mode.split("_")[1]) / 100
            if not expected:
                return True
            overlap = len(set(actual) & set(expected)) / len(expected)
            return overlap >= threshold

        return actual == expected

    def _fuzzy_match(self, a: str, b: str) -> float:
        """Simple fuzzy match score"""
        if a == b:
            return 1.0
        # Normalize and compare
        a_norm = a.lower().strip()
        b_norm = b.lower().strip()
        if a_norm == b_norm:
            return 0.95
        if a_norm in b_norm or b_norm in a_norm:
            return 0.8
        return 0.0
```

---

## 3. VALIDATION RULES

### 3.1 Schema Validation

```python
class SchemaValidator:
    """Validate output schema compliance"""

    def __init__(self, expected_schema: pa.Schema):
        self.expected_schema = expected_schema

    def validate(self, table: pa.Table) -> List[ValidationError]:
        """Validate table against expected schema"""
        errors = []

        # Check all required columns present
        for field in self.expected_schema:
            if field.name not in table.column_names:
                errors.append(ValidationError(
                    field=field.name,
                    error_type="missing_column",
                    message=f"Required column '{field.name}' is missing"
                ))
                continue

            # Check type compatibility
            actual_type = table.schema.field(field.name).type
            if not self._types_compatible(actual_type, field.type):
                errors.append(ValidationError(
                    field=field.name,
                    error_type="type_mismatch",
                    message=f"Expected {field.type}, got {actual_type}"
                ))

        # Check for unexpected columns (warning, not error)
        expected_names = {f.name for f in self.expected_schema}
        for name in table.column_names:
            if name not in expected_names:
                errors.append(ValidationError(
                    field=name,
                    error_type="unexpected_column",
                    message=f"Unexpected column '{name}'",
                    severity="warning"
                ))

        return errors

    def _types_compatible(self, actual: pa.DataType, expected: pa.DataType) -> bool:
        """Check if types are compatible"""
        if actual == expected:
            return True

        # Allow numeric promotions
        numeric_types = {pa.int32(), pa.int64(), pa.float32(), pa.float64()}
        if actual in numeric_types and expected in numeric_types:
            return True

        return False
```

### 3.2 Business Logic Validation

```python
class BusinessRuleValidator:
    """Validate business logic rules"""

    RULES = [
        # Sentiment rules
        ("sentiment_category_matches_score", {
            "condition": lambda r: (
                (r["ai_sentiment_score"] >= 7 and r["ai_sentiment_category"] == "positive") or
                (r["ai_sentiment_score"] <= 3 and r["ai_sentiment_category"] == "negative") or
                (3 < r["ai_sentiment_score"] < 7 and r["ai_sentiment_category"] == "neutral")
            ),
            "message": "Sentiment category doesn't match score"
        }),

        # NPS rules
        ("nps_category_matches_score", {
            "condition": lambda r: (
                (r["user_score_normalized"] >= 9 and r["nps_category"] == "Promoter") or
                (7 <= r["user_score_normalized"] < 9 and r["nps_category"] == "Passive") or
                (r["user_score_normalized"] < 7 and r["nps_category"] == "Detractor") or
                r["user_score_normalized"] is None
            ),
            "message": "NPS category doesn't match score"
        }),

        # Churn rules
        ("churn_level_matches_score", {
            "condition": lambda r: (
                (r["churn_risk_score"] >= 80 and r["churn_risk_level"] == "critical") or
                (60 <= r["churn_risk_score"] < 80 and r["churn_risk_level"] == "high") or
                (40 <= r["churn_risk_score"] < 60 and r["churn_risk_level"] == "medium") or
                (r["churn_risk_score"] < 40 and r["churn_risk_level"] == "low") or
                r["churn_risk_score"] is None
            ),
            "message": "Churn level doesn't match score"
        }),

        # Priority rules
        ("priority_in_range", {
            "condition": lambda r: 0 <= r["review_priority"] <= 100,
            "message": "Priority must be 0-100"
        }),

        # Duplicate rules
        ("duplicate_count_positive", {
            "condition": lambda r: r["duplicate_count"] >= 1,
            "message": "Duplicate count must be at least 1"
        }),

        # Word count rules
        ("word_count_matches_content", {
            "condition": lambda r: (
                abs(r["word_count"] - len(r["normalized_comment"].split())) <= 1
            ),
            "message": "Word count doesn't match content"
        }),
    ]

    def validate(self, table: pa.Table) -> List[ValidationError]:
        """Validate all business rules"""
        errors = []

        for row_idx, row in enumerate(table.to_pylist()):
            for rule_name, rule_def in self.RULES:
                try:
                    if not rule_def["condition"](row):
                        errors.append(ValidationError(
                            row=row_idx,
                            field=rule_name,
                            error_type="business_rule_violation",
                            message=rule_def["message"],
                            actual=str(row)
                        ))
                except (KeyError, TypeError) as e:
                    # Missing or null values - skip rule
                    pass

        return errors
```

### 3.3 Value Range Validation

```python
class RangeValidator:
    """Validate values are within expected ranges"""

    RANGES = {
        "ai_sentiment_score": (0.0, 10.0),
        "ai_sentiment_corrected": (0.0, 10.0),
        "churn_risk_score": (0, 100),
        "review_priority": (0, 100),
        "user_score_normalized": (0.0, 10.0),
        "emotion_satisfaction": (0.0, 1.0),
        "emotion_frustration": (0.0, 1.0),
        "emotion_trust": (0.0, 1.0),
        "emotion_anger": (0.0, 1.0),
        "emotion_disappointment": (0.0, 1.0),
        "emotion_anticipation": (0.0, 1.0),
        "emotion_confusion": (0.0, 1.0),
        "word_count": (0, 10000),
        "duplicate_count": (1, None),  # None = no upper limit
    }

    def validate(self, table: pa.Table) -> List[ValidationError]:
        """Validate all value ranges"""
        errors = []

        for field, (min_val, max_val) in self.RANGES.items():
            if field not in table.column_names:
                continue

            column = table.column(field)
            for idx, value in enumerate(column):
                if value is None:
                    continue

                value = value.as_py()
                if min_val is not None and value < min_val:
                    errors.append(ValidationError(
                        row=idx,
                        field=field,
                        error_type="value_below_range",
                        message=f"Value {value} below minimum {min_val}"
                    ))
                if max_val is not None and value > max_val:
                    errors.append(ValidationError(
                        row=idx,
                        field=field,
                        error_type="value_above_range",
                        message=f"Value {value} above maximum {max_val}"
                    ))

        return errors
```

---

## 4. COMPARISON ENGINE

### 4.1 Result Comparison

```python
from dataclasses import dataclass
from typing import Dict, List

@dataclass
class ComparisonResult:
    """Result of comparing actual vs expected"""
    field: str
    match_rate: float
    total_rows: int
    matching_rows: int
    mismatches: List[Dict]
    passed: bool


class ComparisonEngine:
    """Compare actual output to expected golden dataset"""

    def __init__(self, tolerance_profile: str):
        self.validator = ToleranceValidator(tolerance_profile)

    def compare(
        self,
        actual: pa.Table,
        expected: pa.Table
    ) -> Dict[str, ComparisonResult]:
        """Compare actual vs expected for all columns"""

        results = {}

        # Align by row if needed
        if actual.num_rows != expected.num_rows:
            raise ComparisonError(
                f"Row count mismatch: {actual.num_rows} vs {expected.num_rows}"
            )

        # Compare each column
        for field in expected.schema:
            if field.name not in actual.column_names:
                results[field.name] = ComparisonResult(
                    field=field.name,
                    match_rate=0.0,
                    total_rows=expected.num_rows,
                    matching_rows=0,
                    mismatches=[{"error": "Column missing"}],
                    passed=False
                )
                continue

            result = self._compare_column(
                actual.column(field.name),
                expected.column(field.name),
                field.name,
                field.type
            )
            results[field.name] = result

        return results

    def _compare_column(
        self,
        actual_col: pa.Array,
        expected_col: pa.Array,
        field_name: str,
        field_type: pa.DataType
    ) -> ComparisonResult:
        """Compare a single column"""

        mismatches = []
        matching = 0

        for idx in range(len(actual_col)):
            actual_val = actual_col[idx].as_py() if actual_col[idx].is_valid else None
            expected_val = expected_col[idx].as_py() if expected_col[idx].is_valid else None

            if self._values_match(actual_val, expected_val, field_name, field_type):
                matching += 1
            else:
                if len(mismatches) < 10:  # Limit stored mismatches
                    mismatches.append({
                        "row": idx,
                        "actual": actual_val,
                        "expected": expected_val
                    })

        match_rate = matching / len(actual_col) if len(actual_col) > 0 else 1.0
        threshold = self._get_threshold(field_name)

        return ComparisonResult(
            field=field_name,
            match_rate=match_rate,
            total_rows=len(actual_col),
            matching_rows=matching,
            mismatches=mismatches,
            passed=match_rate >= threshold
        )

    def _values_match(
        self,
        actual: Any,
        expected: Any,
        field_name: str,
        field_type: pa.DataType
    ) -> bool:
        """Check if values match within tolerance"""

        # Both null
        if actual is None and expected is None:
            return True

        # One null
        if actual is None or expected is None:
            return False

        # Numeric comparison
        if pa.types.is_floating(field_type) or pa.types.is_integer(field_type):
            return self.validator.validate_numeric(actual, expected, field_name)

        # List comparison
        if pa.types.is_list(field_type):
            return self.validator.validate_list(actual, expected, field_name)

        # String/categorical comparison
        if pa.types.is_string(field_type):
            return self.validator.validate_categorical(actual, expected, field_name)

        # Exact match for other types
        return actual == expected

    def _get_threshold(self, field_name: str) -> float:
        """Get match rate threshold for field"""
        profile = self.validator.profile

        # Exact fields need 100%
        if field_name in ["is_duplicate", "duplicate_group_id", "word_count"]:
            return 1.0

        # Get from profile or default
        cat_mode = profile["tolerances"].get("categorical", "exact")
        if cat_mode.startswith("fuzzy_"):
            return int(cat_mode.split("_")[1]) / 100

        return 0.95  # Default 95%
```

### 4.2 Report Generation

```python
class ValidationReport:
    """Generate validation report"""

    def __init__(
        self,
        dataset_name: str,
        schema_errors: List[ValidationError],
        business_errors: List[ValidationError],
        range_errors: List[ValidationError],
        comparison_results: Dict[str, ComparisonResult]
    ):
        self.dataset_name = dataset_name
        self.schema_errors = schema_errors
        self.business_errors = business_errors
        self.range_errors = range_errors
        self.comparison_results = comparison_results

    @property
    def passed(self) -> bool:
        """Overall pass/fail"""
        if self.schema_errors:
            return False
        if any(e.severity == "error" for e in self.business_errors):
            return False
        if self.range_errors:
            return False
        if any(not r.passed for r in self.comparison_results.values()):
            return False
        return True

    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization"""
        return {
            "dataset": self.dataset_name,
            "passed": self.passed,
            "summary": {
                "schema_errors": len(self.schema_errors),
                "business_errors": len(self.business_errors),
                "range_errors": len(self.range_errors),
                "columns_compared": len(self.comparison_results),
                "columns_passed": sum(1 for r in self.comparison_results.values() if r.passed),
            },
            "schema_errors": [e.to_dict() for e in self.schema_errors],
            "business_errors": [e.to_dict() for e in self.business_errors[:20]],
            "range_errors": [e.to_dict() for e in self.range_errors[:20]],
            "comparison": {
                name: {
                    "match_rate": r.match_rate,
                    "passed": r.passed,
                    "mismatches": r.mismatches[:5]
                }
                for name, r in self.comparison_results.items()
            }
        }

    def to_markdown(self) -> str:
        """Generate Markdown report"""
        lines = [
            f"# Validation Report: {self.dataset_name}",
            "",
            f"**Status:** {'PASSED' if self.passed else 'FAILED'}",
            "",
            "## Summary",
            "",
            f"- Schema errors: {len(self.schema_errors)}",
            f"- Business rule violations: {len(self.business_errors)}",
            f"- Range violations: {len(self.range_errors)}",
            f"- Columns compared: {len(self.comparison_results)}",
            f"- Columns passed: {sum(1 for r in self.comparison_results.values() if r.passed)}",
            "",
            "## Column Comparison",
            "",
            "| Column | Match Rate | Status |",
            "|--------|------------|--------|",
        ]

        for name, result in self.comparison_results.items():
            status = "PASS" if result.passed else "FAIL"
            lines.append(f"| {name} | {result.match_rate:.1%} | {status} |")

        return "\n".join(lines)
```

---

## 5. TEST CASES

### 5.1 Edge Cases Dataset

```yaml
# Edge cases that must be handled correctly

edge_cases:
  - id: empty_comment
    input:
      customer_comment: ""
      user_score: 5
    expected:
      word_count: 0
      ai_sentiment_category: "neutral"

  - id: very_long_comment
    input:
      customer_comment: "[2000+ character comment...]"
      user_score: 7
    expected:
      word_count: ">200"
      truncated: false

  - id: special_characters
    input:
      customer_comment: "¡Excelente! 😀 Muy bueno @empresa #servicio"
      user_score: 9
    expected:
      ai_sentiment_category: "positive"
      emotion_primary: "satisfaction"

  - id: null_score
    input:
      customer_comment: "Buen servicio"
      user_score: null
    expected:
      nps_category: null
      discrepancy_detected: false

  - id: score_boundary_9
    input:
      customer_comment: "Excelente servicio"
      user_score: 9
    expected:
      nps_category: "Promoter"

  - id: score_boundary_7
    input:
      customer_comment: "Bien pero podría mejorar"
      user_score: 7
    expected:
      nps_category: "Passive"

  - id: mixed_language
    input:
      customer_comment: "Very good service, excelente atención"
      user_score: 8
    expected:
      # Should handle mixed language gracefully

  - id: only_numbers
    input:
      customer_comment: "12345 67890"
      user_score: 5
    expected:
      word_count: 2

  - id: extreme_negative
    input:
      customer_comment: "Horrible, terrible, pésimo, lo peor que he visto"
      user_score: 1
    expected:
      ai_sentiment_score: "<3"
      ai_sentiment_category: "negative"
      churn_risk_level: "critical"

  - id: sarcasm
    input:
      customer_comment: "Sí claro, el 'mejor' servicio del mundo"
      user_score: 2
    expected:
      # LLM should detect sarcasm
      ai_sentiment_category: "negative"

  - id: duplicate_exact
    input:
      - customer_comment: "Muy buen servicio"
      - customer_comment: "Muy buen servicio"
    expected:
      - is_duplicate: false
      - is_duplicate: true
        duplicate_of: 0
```

### 5.2 Duplicate Detection Tests

```python
class DuplicateDetectionTests:
    """Test cases for duplicate detection"""

    TEST_CASES = [
        # Exact duplicates
        {
            "name": "exact_duplicate",
            "input": [
                "Excelente servicio",
                "Excelente servicio",
            ],
            "expected_duplicates": [False, True],
            "expected_groups": [0, 0],
        },

        # Case difference (should be duplicate after normalization)
        {
            "name": "case_insensitive",
            "input": [
                "Excelente servicio",
                "EXCELENTE SERVICIO",
            ],
            "expected_duplicates": [False, True],
        },

        # Whitespace difference
        {
            "name": "whitespace_normalized",
            "input": [
                "Excelente  servicio",
                "Excelente servicio",
            ],
            "expected_duplicates": [False, True],
        },

        # No duplicates
        {
            "name": "no_duplicates",
            "input": [
                "Excelente servicio",
                "Mal servicio",
                "Buen producto",
            ],
            "expected_duplicates": [False, False, False],
        },

        # Multiple groups
        {
            "name": "multiple_groups",
            "input": [
                "Comentario A",
                "Comentario B",
                "Comentario A",
                "Comentario B",
                "Comentario C",
            ],
            "expected_duplicates": [False, False, True, True, False],
            "expected_groups": [0, 1, 0, 1, 4],
            "expected_counts": [2, 2, 2, 2, 1],
        },
    ]
```

---

## 6. REGRESSION TESTS

### 6.1 Regression Test Suite

```python
class RegressionTestSuite:
    """Prevent regressions in pipeline output"""

    def __init__(self, baseline_path: str):
        self.baseline_path = baseline_path
        self.baselines: Dict[str, pa.Table] = {}

    async def run(self, dataset: str, actual: pa.Table) -> RegressionResult:
        """Run regression tests against baseline"""

        baseline = await self._load_baseline(dataset)

        if baseline is None:
            # No baseline exists, create one
            await self._save_baseline(dataset, actual)
            return RegressionResult(
                dataset=dataset,
                status="baseline_created",
                message="New baseline created"
            )

        # Compare with baseline
        differences = self._compare_with_baseline(actual, baseline)

        if differences:
            return RegressionResult(
                dataset=dataset,
                status="regression_detected",
                differences=differences,
                message=f"Found {len(differences)} regressions"
            )

        return RegressionResult(
            dataset=dataset,
            status="passed",
            message="No regressions detected"
        )

    def _compare_with_baseline(
        self,
        actual: pa.Table,
        baseline: pa.Table
    ) -> List[Dict]:
        """Compare actual output with baseline"""

        differences = []

        # Check row count
        if actual.num_rows != baseline.num_rows:
            differences.append({
                "type": "row_count_change",
                "baseline": baseline.num_rows,
                "actual": actual.num_rows
            })

        # Check schema changes
        for field in baseline.schema:
            if field.name not in actual.column_names:
                differences.append({
                    "type": "column_removed",
                    "column": field.name
                })

        # Check for new columns
        baseline_cols = {f.name for f in baseline.schema}
        for field in actual.schema:
            if field.name not in baseline_cols:
                differences.append({
                    "type": "column_added",
                    "column": field.name
                })

        # Check value distributions
        for field in baseline.schema:
            if field.name not in actual.column_names:
                continue

            dist_change = self._check_distribution_change(
                actual.column(field.name),
                baseline.column(field.name)
            )
            if dist_change:
                differences.append({
                    "type": "distribution_change",
                    "column": field.name,
                    **dist_change
                })

        return differences

    def _check_distribution_change(
        self,
        actual: pa.Array,
        baseline: pa.Array
    ) -> Optional[Dict]:
        """Check for significant distribution changes"""

        # For numeric fields, check mean/std change
        if pa.types.is_floating(actual.type) or pa.types.is_integer(actual.type):
            actual_mean = pc.mean(actual).as_py()
            baseline_mean = pc.mean(baseline).as_py()

            if actual_mean and baseline_mean:
                change = abs(actual_mean - baseline_mean) / baseline_mean
                if change > 0.1:  # 10% change threshold
                    return {
                        "baseline_mean": baseline_mean,
                        "actual_mean": actual_mean,
                        "change_percent": change * 100
                    }

        # For categorical, check distribution
        if pa.types.is_string(actual.type):
            actual_counts = pc.value_counts(actual)
            baseline_counts = pc.value_counts(baseline)

            # Compare top categories
            # ... implementation

        return None
```

---

## 7. RUNNING VALIDATION

### 7.1 CLI Commands

```bash
# Run validation against golden dataset
feedback-arrow validate golden spanish_small

# Run full validation suite
feedback-arrow validate golden --all

# Run with specific tolerance profile
feedback-arrow validate golden spanish_medium --tolerance standard

# Generate validation report
feedback-arrow validate golden spanish_small --report validation_report.md

# Run regression tests
feedback-arrow validate regression spanish_small

# Update baseline
feedback-arrow validate baseline update spanish_small
```

### 7.2 CI/CD Integration

```yaml
# .github/workflows/validate.yml

name: Validation Suite

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: pip install -e .[dev]

      - name: Start Ollama
        run: |
          curl -fsSL https://ollama.ai/install.sh | sh
          ollama pull llama3:8b

      - name: Run quick validation
        run: feedback-arrow validate golden spanish_small --tolerance strict

      - name: Run full validation (on main only)
        if: github.ref == 'refs/heads/main'
        run: feedback-arrow validate golden --all --report validation.md

      - name: Upload validation report
        uses: actions/upload-artifact@v4
        with:
          name: validation-report
          path: validation.md
```

---

## SUMMARY

```
VALIDATION SUITE:
├── Golden Datasets
│   ├── spanish/ (small, medium, large, edge cases)
│   ├── english/ (small)
│   └── expected/ outputs
│
├── Tolerance Profiles
│   ├── strict (edge cases)
│   ├── standard (CI/CD)
│   ├── relaxed (scale tests)
│   └── exact (deterministic)
│
├── Validation Rules
│   ├── Schema validation
│   ├── Business rules
│   └── Range validation
│
├── Comparison Engine
│   ├── Numeric tolerance
│   ├── Categorical fuzzy match
│   └── List overlap
│
├── Test Cases
│   ├── Edge cases (empty, long, special chars)
│   └── Duplicate detection
│
└── Regression Tests
    ├── Baseline comparison
    └── Distribution change detection
```

---

**Document Version:** 1.0.0
**Created:** 2025-12-19
**Purpose:** Validation and testing specification
