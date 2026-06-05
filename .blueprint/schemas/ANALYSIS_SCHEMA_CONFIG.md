# Analysis Schema Configuration

**Version:** 1.0.0
**Date:** 2025-12-15
**Purpose:** Define schema-driven, per-client configurable analysis output

---

## DESIGN PRINCIPLE

```
Schemas are configuration, not code.
Adding features = adding schema modules, not refactoring.
Each client can enable/disable analysis modules independently.
```

---

## 1. SCHEMA STRUCTURE

### 1.1 Base Schema (Required)

Minimum fields the pipeline requires to function. Always computed.

```yaml
base_schema:
  version: "1.0.0"
  fields:
    - name: sentiment_score
      type: float
      range: [0, 10]
      source: llm
      required: true
      description: "Core sentiment, needed for downstream metrics"

    - name: sentiment_category
      type: enum
      values: ["positive", "neutral", "negative"]
      source: local  # Derived from sentiment_score
      required: true

    - name: word_count
      type: integer
      source: local  # Computed pre-LLM
      required: true
```

### 1.2 Optional Modules

Clients enable/disable these independently.

```yaml
modules:
  emotions:
    enabled: false  # Client toggles
    fields:
      - name: emotion_primary
        type: string
        source: llm
      - name: emotion_scores
        type: object
        source: llm
        schema:
          satisfaccion: float
          frustracion: float
          confianza: float
          enojo: float
          decepcion: float
          anticipacion: float
          confusion: float

  churn_analysis:
    enabled: false
    fields:
      - name: churn_risk
        type: integer
        range: [0, 100]
        source: llm
      - name: churn_signals
        type: array
        source: llm
      - name: churn_urgency
        type: string
        source: llm
      - name: churn_recommendation
        type: string
        source: llm

  pain_points:
    enabled: false
    fields:
      - name: pain_point_primary
        type: string
        source: llm
      - name: pain_point_secondary
        type: string
        source: llm
      - name: pain_point_keywords
        type: array
        source: llm

  deep_insights:
    enabled: false
    fields:
      - name: improvement_suggestions
        type: array
        source: llm
      - name: keywords_extracted
        type: array
        source: llm
      - name: actionability_hints
        type: object
        source: llm
```

---

## 2. SOURCE TYPES

### 2.1 Field Source Classification

| Source | Computed By | Cached | Example |
|--------|-------------|--------|---------|
| `llm` | LLM response | Yes | `sentiment_score`, `emotion_primary` |
| `local` | Post-processing | No | `sentiment_category`, `nps_category` |
| `pre` | Pre-processing | No | `word_count`, `is_duplicate` |
| `input` | User data | No | `user_score`, `customer_comment` |

### 2.2 Never-Cached Fields

These are always computed fresh, never stored in cache:

```yaml
never_cache:
  - nps_category        # Ground truth from user_score
  - review_priority     # Composite metric, may change
  - is_duplicate        # Dataset-specific
  - duplicate_count     # Dataset-specific
```

---

## 3. CLIENT CONFIGURATION

### 3.1 Configuration File Per Client

```yaml
# client_configs/acme_corp.yaml
client_id: acme_corp
schema_version: "1.0.0"

modules:
  emotions: true
  churn_analysis: true
  pain_points: true
  deep_insights: false  # Not needed for this client

language: es
cost_ceiling_per_comment: 0.001  # USD

custom_fields: []  # Future: client-specific fields
```

### 3.2 Default Configuration

```yaml
# client_configs/_default.yaml
client_id: _default
schema_version: "1.0.0"

modules:
  emotions: true
  churn_analysis: true
  pain_points: true
  deep_insights: true

language: es
cost_ceiling_per_comment: 0.005
```

---

## 4. SCHEMA-TO-PROMPT BINDING

### 4.1 Prompt Assembly

The system prompt is assembled based on enabled modules:

```python
def build_prompt(config: ClientConfig, language_pack: LanguagePack) -> str:
    """Assemble prompt from enabled modules"""

    sections = [language_pack.get_base_prompt()]

    if config.modules.emotions:
        sections.append(language_pack.get_emotion_prompt())

    if config.modules.churn_analysis:
        sections.append(language_pack.get_churn_prompt())

    if config.modules.pain_points:
        sections.append(language_pack.get_pain_point_prompt())

    if config.modules.deep_insights:
        sections.append(language_pack.get_insights_prompt())

    return "\n\n".join(sections)
```

### 4.2 JSON Schema Assembly

Similarly, the expected response schema is assembled:

```python
def build_response_schema(config: ClientConfig) -> dict:
    """Build JSON Schema for structured output"""

    properties = {
        "sentiment_score": {"type": "number", "minimum": 0, "maximum": 10}
    }
    required = ["sentiment_score"]

    if config.modules.emotions:
        properties["emotion_primary"] = {"type": "string"}
        properties["emotion_scores"] = {"type": "object"}
        required.extend(["emotion_primary", "emotion_scores"])

    # ... etc for each module

    return {
        "type": "object",
        "properties": properties,
        "required": required,
        "additionalProperties": False
    }
```

---

## 5. CACHE KEY GENERATION

### 5.1 Schema-Aware Cache Keys

Cache key includes schema configuration hash:

```python
def generate_cache_key(
    comment: str,
    language: str,
    schema_config: ClientConfig
) -> str:
    """
    Cache key includes schema hash.
    Different schema = different cache entry.
    """
    normalized = normalize_text(comment)
    schema_hash = hash_schema_config(schema_config)  # Hash of enabled modules

    content = f"{language}:{schema_hash}:{normalized}"
    return hashlib.sha256(content.encode()).hexdigest()[:16]

def hash_schema_config(config: ClientConfig) -> str:
    """Stable hash of schema configuration"""
    enabled = sorted([
        name for name, enabled in config.modules.items() if enabled
    ])
    return hashlib.md5(":".join(enabled).encode()).hexdigest()[:8]
```

### 5.2 Cache Invalidation

Schema change invalidates cache automatically:

```
Client enables `deep_insights` module
→ schema_hash changes
→ cache keys change
→ old cache entries won't match
→ fresh LLM calls for new schema
```

---

## 6. COST ESTIMATION

### 6.1 Per-Module Token Estimates

```yaml
token_estimates:
  base:
    input: 50      # Base prompt overhead
    output: 20     # sentiment_score only

  emotions:
    input: 100     # Emotion instructions
    output: 80     # 7 emotion scores

  churn_analysis:
    input: 150     # Churn detection instructions
    output: 100    # Risk + signals + recommendation

  pain_points:
    input: 200     # Category taxonomy
    output: 50     # Primary + secondary + keywords

  deep_insights:
    input: 100     # Insights instructions
    output: 150    # Suggestions + keywords
```

### 6.2 Cost Calculator

```python
def estimate_cost_per_comment(
    config: ClientConfig,
    provider: ProviderCapabilities
) -> float:
    """Estimate cost based on enabled modules"""

    input_tokens = TOKEN_ESTIMATES["base"]["input"]
    output_tokens = TOKEN_ESTIMATES["base"]["output"]

    for module, enabled in config.modules.items():
        if enabled:
            input_tokens += TOKEN_ESTIMATES[module]["input"]
            output_tokens += TOKEN_ESTIMATES[module]["output"]

    cost = (
        (input_tokens / 1000) * provider.cost_per_1k_input +
        (output_tokens / 1000) * provider.cost_per_1k_output
    )

    return cost
```

### 6.3 Cost Transparency in API

```json
// POST /api/analyze response
{
  "task_id": "abc123",
  "estimated_cost": {
    "per_comment_usd": 0.00045,
    "total_usd": 4.50,
    "breakdown": {
      "base": 0.00010,
      "emotions": 0.00015,
      "churn_analysis": 0.00012,
      "pain_points": 0.00008
    }
  },
  "modules_enabled": ["emotions", "churn_analysis", "pain_points"]
}
```

---

## 7. OUTPUT COLUMN MAPPING

### 7.1 Module to Column Mapping

```yaml
column_mapping:
  base:
    - sentiment_score → "AI Sentiment"
    - sentiment_category → "Sentiment Category"

  emotions:
    - emotion_primary → "Emotion"
    - emotion_scores.satisfaccion → "Emotion: Satisfaction"
    - emotion_scores.frustracion → "Emotion: Frustration"
    # ... etc

  churn_analysis:
    - churn_risk → "Churn Risk"
    - churn_signals → "Churn Signals"
    - churn_urgency → "Churn Risk Temporal Urgency"
    - churn_recommendation → "Churn Risk Recommended Action"

  pain_points:
    - pain_point_primary → "Pain Point Category (Primary)"
    - pain_point_secondary → "Pain Point Category (Secondary)"
    - pain_point_keywords → "Pain Point Keywords"
```

### 7.2 Dynamic Column Selection

Export includes only columns for enabled modules:

```python
def get_export_columns(config: ClientConfig) -> List[str]:
    """Return columns based on enabled modules"""

    columns = list(COLUMN_MAPPING["base"])

    for module, enabled in config.modules.items():
        if enabled:
            columns.extend(COLUMN_MAPPING[module])

    return columns
```

---

## 8. VALIDATION

### 8.1 Response Validation

```python
def validate_llm_response(
    response: dict,
    config: ClientConfig
) -> ValidationResult:
    """Validate LLM response matches expected schema"""

    schema = build_response_schema(config)

    try:
        jsonschema.validate(response, schema)
        return ValidationResult(valid=True)
    except jsonschema.ValidationError as e:
        return ValidationResult(valid=False, error=str(e))
```

### 8.2 Fallback for Invalid Responses

```python
def handle_invalid_response(
    response: dict,
    config: ClientConfig
) -> dict:
    """Provide defaults for missing fields"""

    defaults = {
        "sentiment_score": 5.0,  # Neutral default
        "emotion_primary": "neutral",
        "churn_risk": 0,
        # ... etc
    }

    schema = build_response_schema(config)

    for field in schema["required"]:
        if field not in response:
            response[field] = defaults.get(field)

    return response
```

---

## SUMMARY

```
SCHEMA-DRIVEN APPROACH:
- Base schema: always computed, pipeline requirements
- Optional modules: client enables/disables
- Source types: llm | local | pre | input
- Never-cache fields: nps_category, review_priority, duplicates

CONFIGURATION:
- Per-client YAML files
- Schema version tracked
- Cost ceiling configurable

BINDING:
- Schema → Prompt assembly
- Schema → JSON Schema for LLM
- Schema → Cache key hash
- Schema → Export columns

COST:
- Per-module token estimates
- Transparent cost breakdown in API
- Client cost ceilings enforced
```

---

**Document Version:** 1.0.0
**Generated:** 2025-12-15
**Resolves:** Gap 1 (Analysis JSON Schema) + Gap 2 partial (Prompt binding)
