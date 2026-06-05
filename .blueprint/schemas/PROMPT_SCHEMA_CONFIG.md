# Prompt Schema Configuration

**Version:** 1.0.0
**Date:** 2025-12-15
**Purpose:** Schema-driven prompt templates with model-family adaptation
**Stack Focus:** Arrow + Cloudflare + On-Premise (Local-First)

---

## DESIGN PRINCIPLE

```
Prompts are configuration, not code.
Prompts adapt to model families without code changes.
Language variables interpolate from Language Packs.
Local models (Ollama/vLLM) are first-class citizens.
```

---

## 1. DIRECTORY STRUCTURE

```
prompts/
├── _base.yaml              # Shared base instructions
├── modules/
│   ├── sentiment.yaml      # Sentiment analysis prompt
│   ├── emotions.yaml       # Emotion detection prompt
│   ├── churn.yaml          # Churn risk prompt
│   ├── pain_points.yaml    # Pain point classification prompt
│   └── insights.yaml       # Deep insights prompt
├── formats/
│   ├── json_instruct.yaml  # For models needing in-prompt JSON instructions
│   └── structured.yaml     # For models with native structured output
└── examples/
    ├── sentiment_examples.yaml
    └── churn_examples.yaml
```

---

## 2. PROMPT SCHEMA STRUCTURE

### 2.1 Module Prompt Schema

```yaml
# prompts/modules/sentiment.yaml
module: sentiment
version: "1.0.0"

# Token estimates for cost calculation
token_estimate:
  base: 80
  per_example: 50

# Model-family variants
variants:
  # Local models (Ollama, vLLM, llama.cpp) - DEFAULT for on-premise
  llama:
    system: |
      You are a sentiment analyzer for customer feedback in {LANGUAGE_NAME}.

      Analyze the sentiment and return a score from 0-10:
      - 0-3: Negative
      - 4-6: Neutral
      - 7-10: Positive

      Consider these {LANGUAGE_NAME} sentiment modifiers:
      - Negation words: {NEGATION_WORDS}
      - Intensifiers: {INTENSIFIER_WORDS}

      {JSON_FORMAT_INSTRUCTIONS}

    user: |
      Analyze this feedback:
      "{COMMENT}"

  # OpenAI models (gpt-4o-mini, gpt-4o)
  openai:
    system: |
      You are a sentiment analyzer for {LANGUAGE_NAME} customer feedback.

      Scoring guide (0-10 scale):
      - 0-3: Negative sentiment
      - 4-6: Neutral sentiment
      - 7-10: Positive sentiment

      {LANGUAGE_NAME} modifiers to consider:
      • Negation: {NEGATION_WORDS}
      • Intensifiers: {INTENSIFIER_WORDS}

    user: |
      Analyze: "{COMMENT}"

  # Anthropic models (Claude)
  anthropic:
    system: |
      <role>Sentiment analyzer for {LANGUAGE_NAME} customer feedback</role>

      <scoring>
      0-3: Negative
      4-6: Neutral
      7-10: Positive
      </scoring>

      <language_modifiers>
      Negation: {NEGATION_WORDS}
      Intensifiers: {INTENSIFIER_WORDS}
      </language_modifiers>

    user: |
      <feedback>{COMMENT}</feedback>

      Analyze the sentiment.

# Output schema (same across all variants)
output_schema:
  type: object
  properties:
    sentiment_score:
      type: number
      minimum: 0
      maximum: 10
  required: [sentiment_score]
```

### 2.2 Complex Module Example (Churn)

```yaml
# prompts/modules/churn.yaml
module: churn
version: "1.0.0"

token_estimate:
  base: 200
  per_example: 100

# Cacheable prefix (stable for prompt caching)
cacheable_prefix:
  llama: |
    You analyze customer feedback for churn risk indicators.

    Risk levels:
    - CRITICAL (80-100): Immediate intervention needed
    - HIGH (60-79): Priority attention within 48h
    - MEDIUM (40-59): Monitor and engage within 1 week
    - LOW (0-39): Standard monitoring

    Signals to detect:
    - Exit threats: {EXIT_THREAT_PATTERNS}
    - Competitor mentions: {COMPETITOR_NAMES}
    - Technical failures: {TECHNICAL_FAILURE_PATTERNS}
    - Cost concerns: {COST_CONCERN_PATTERNS}

  openai: |
    # Churn Risk Analyzer

    ## Risk Levels
    | Score | Level | Action |
    |-------|-------|--------|
    | 80-100 | CRITICAL | Immediate intervention |
    | 60-79 | HIGH | 48h priority |
    | 40-59 | MEDIUM | 1 week follow-up |
    | 0-39 | LOW | Standard monitoring |

    ## Detection Patterns ({LANGUAGE_NAME})
    - Exit threats: {EXIT_THREAT_PATTERNS}
    - Competitors: {COMPETITOR_NAMES}
    - Technical issues: {TECHNICAL_FAILURE_PATTERNS}
    - Cost concerns: {COST_CONCERN_PATTERNS}

  anthropic: |
    <role>Churn risk analyzer</role>

    <risk_levels>
    CRITICAL (80-100): Immediate intervention
    HIGH (60-79): 48h priority
    MEDIUM (40-59): 1 week follow-up
    LOW (0-39): Standard monitoring
    </risk_levels>

    <detection_patterns language="{LANGUAGE_CODE}">
    Exit threats: {EXIT_THREAT_PATTERNS}
    Competitors: {COMPETITOR_NAMES}
    Technical: {TECHNICAL_FAILURE_PATTERNS}
    Cost: {COST_CONCERN_PATTERNS}
    </detection_patterns>

# Variable suffix (changes per request)
variable_suffix:
  all: |
    User rating: {USER_SCORE}/10
    Comment: "{COMMENT}"

output_schema:
  type: object
  properties:
    churn_risk:
      type: integer
      minimum: 0
      maximum: 100
    churn_signals:
      type: array
      items:
        type: string
    churn_urgency:
      type: string
      enum: [ALREADY_CHURNED, IMMEDIATE, SHORT_TERM, MEDIUM_TERM, null]
    churn_recommendation:
      type: string
  required: [churn_risk, churn_signals]
```

---

## 3. MODEL FAMILY CONFIGURATION

### 3.1 Model-to-Family Mapping

```yaml
# config/model_families.yaml
families:
  llama:
    models:
      - "llama3:*"
      - "llama3.1:*"
      - "mistral:*"
      - "mixtral:*"
      - "qwen:*"
      - "phi:*"
    features:
      structured_output: true  # Ollama 0.5+ supports this
      prompt_caching: false
      preferred_format: json_instruct

  openai:
    models:
      - "gpt-4o-mini"
      - "gpt-4o"
      - "gpt-4-turbo"
    features:
      structured_output: true  # Native json_schema
      prompt_caching: true
      preferred_format: structured

  anthropic:
    models:
      - "claude-3-haiku-*"
      - "claude-3-5-sonnet-*"
      - "claude-3-opus-*"
    features:
      structured_output: true  # Via tool_use
      prompt_caching: true
      preferred_format: structured

  # Fallback for unknown models
  generic:
    models: ["*"]
    features:
      structured_output: false
      prompt_caching: false
      preferred_format: json_instruct
```

### 3.2 Format Instructions

```yaml
# prompts/formats/json_instruct.yaml
# For models without native structured output

format_instruction: |
  Respond with valid JSON only. No explanation, no markdown.

  Required format:
  {JSON_SCHEMA_EXAMPLE}

# prompts/formats/structured.yaml
# For models with native structured output

format_instruction: null  # Handled by API parameter
```

---

## 4. LANGUAGE VARIABLE INTERPOLATION

### 4.1 Variable Sources

Variables come from Language Packs:

```yaml
# language_packs/es/variables.yaml
LANGUAGE_NAME: "Spanish"
LANGUAGE_CODE: "es"

NEGATION_WORDS: "no, nunca, jamás, tampoco, ni"
INTENSIFIER_WORDS: "muy, mucho, demasiado, extremadamente, bastante"

EXIT_THREAT_PATTERNS: "cancelar, dar de baja, cambiar proveedor, me voy"
COMPETITOR_NAMES: "Tigo, Claro, Copaco, Personal, Movistar"
TECHNICAL_FAILURE_PATTERNS: "no funciona, se cae, sin servicio, lento"
COST_CONCERN_PATTERNS: "caro, costoso, precio alto, muy caro"

EMOTION_CATEGORIES: |
  - satisfaccion: customer satisfaction, happiness
  - frustracion: frustration, annoyance
  - confianza: trust, confidence
  - enojo: anger, rage
  - decepcion: disappointment
  - anticipacion: anticipation, expectation
  - confusion: confusion, uncertainty
```

### 4.2 Interpolation Process

```python
def interpolate_prompt(
    template: str,
    language_pack: LanguagePack,
    request_vars: dict
) -> str:
    """
    Interpolate variables into prompt template.

    Order of precedence:
    1. Request variables (COMMENT, USER_SCORE)
    2. Language pack variables (NEGATION_WORDS, etc.)
    3. Schema-derived variables (JSON_SCHEMA_EXAMPLE)
    """

    variables = {}

    # Language pack variables
    variables.update(language_pack.get_variables())

    # Request-specific variables
    variables.update(request_vars)

    # Interpolate
    return template.format(**variables)
```

---

## 5. PROMPT ASSEMBLY

### 5.1 Assembly Pipeline

```python
def assemble_prompt(
    config: ClientConfig,
    model_family: str,
    language_pack: LanguagePack,
    comment: str,
    user_score: Optional[float] = None
) -> PromptPair:
    """
    Assemble complete prompt from schema configuration.

    Returns:
        PromptPair(system=str, user=str)
    """

    # 1. Load base prompt
    system_parts = [load_prompt("_base", model_family)]

    # 2. Add enabled modules
    for module, enabled in config.modules.items():
        if enabled:
            module_prompt = load_prompt(f"modules/{module}", model_family)
            system_parts.append(module_prompt.cacheable_prefix)

    # 3. Add format instructions if needed
    if not MODEL_FAMILIES[model_family].structured_output:
        format_instr = load_prompt("formats/json_instruct", model_family)
        system_parts.append(format_instr)

    # 4. Interpolate language variables
    system_prompt = "\n\n".join(system_parts)
    system_prompt = interpolate_prompt(
        system_prompt,
        language_pack,
        {}
    )

    # 5. Build user prompt with comment
    user_prompt = interpolate_prompt(
        get_user_template(config, model_family),
        language_pack,
        {"COMMENT": comment, "USER_SCORE": user_score or "N/A"}
    )

    return PromptPair(system=system_prompt, user=user_prompt)
```

### 5.2 Prompt Caching Optimization

```python
def get_cacheable_prefix(
    config: ClientConfig,
    model_family: str,
    language_pack: LanguagePack
) -> str:
    """
    Get the stable prefix for prompt caching.

    For OpenAI/Anthropic: This prefix is cached server-side.
    Changes to this invalidate the cache.
    """

    # Only system prompt parts that don't change per-request
    parts = [load_prompt("_base", model_family)]

    for module, enabled in config.modules.items():
        if enabled:
            parts.append(
                load_prompt(f"modules/{module}", model_family).cacheable_prefix
            )

    prefix = "\n\n".join(parts)
    return interpolate_prompt(prefix, language_pack, {})

def get_cache_prefix_hash(prefix: str) -> str:
    """Hash for tracking prefix changes"""
    return hashlib.md5(prefix.encode()).hexdigest()[:8]
```

---

## 6. ON-PREMISE OPTIMIZATIONS

### 6.1 Local Model Considerations

```yaml
# config/on_premise.yaml
on_premise:
  # Default to llama family prompts
  default_model_family: llama

  # Simpler prompts for smaller models
  small_model_mode:
    enabled: false
    threshold_params: 7B  # Models below this get simplified prompts
    simplifications:
      - Remove markdown formatting
      - Shorter examples
      - Single-task focus (no multi-module in one call)

  # Batch prompt optimization
  batching:
    # Local models: smaller batches, single prompt per batch
    strategy: single_comment_per_call
    # vLLM: can handle batch prompts
    vllm_batch_prompt: true
```

### 6.2 Fallback Prompt (Minimal)

```yaml
# prompts/modules/sentiment_minimal.yaml
# For resource-constrained on-premise deployments

module: sentiment
variant: minimal

variants:
  llama:
    system: |
      Rate sentiment 0-10. Return JSON: {"sentiment_score": N}
    user: |
      "{COMMENT}"
```

---

## 7. PROMPT VERSIONING

### 7.1 Version Tracking

```yaml
# prompts/_manifest.yaml
manifest_version: "1.0.0"
last_updated: "2025-12-15"

modules:
  sentiment:
    version: "1.0.0"
    hash: "a1b2c3d4"
  emotions:
    version: "1.0.0"
    hash: "e5f6g7h8"
  churn:
    version: "1.2.0"  # Updated
    hash: "i9j0k1l2"
  pain_points:
    version: "1.0.0"
    hash: "m3n4o5p6"
  insights:
    version: "1.0.0"
    hash: "q7r8s9t0"
```

### 7.2 Cache Invalidation on Prompt Change

```python
def should_invalidate_cache(
    cached_prompt_hash: str,
    current_prompt_hash: str
) -> bool:
    """
    Invalidate cache if prompt changed.
    Different prompt = potentially different output.
    """
    return cached_prompt_hash != current_prompt_hash
```

---

## 8. EXAMPLE: COMPLETE ASSEMBLED PROMPT

### 8.1 For Ollama (Local, Default)

**System Prompt:**
```
You are a sentiment analyzer for customer feedback in Spanish.

Analyze the sentiment and return a score from 0-10:
- 0-3: Negative
- 4-6: Neutral
- 7-10: Positive

Consider these Spanish sentiment modifiers:
- Negation words: no, nunca, jamás, tampoco, ni
- Intensifiers: muy, mucho, demasiado, extremadamente, bastante

You analyze customer feedback for churn risk indicators.

Risk levels:
- CRITICAL (80-100): Immediate intervention needed
- HIGH (60-79): Priority attention within 48h
- MEDIUM (40-59): Monitor and engage within 1 week
- LOW (0-39): Standard monitoring

Signals to detect:
- Exit threats: cancelar, dar de baja, cambiar proveedor, me voy
- Competitor mentions: Tigo, Claro, Copaco, Personal, Movistar
- Technical failures: no funciona, se cae, sin servicio, lento
- Cost concerns: caro, costoso, precio alto, muy caro

Respond with valid JSON only. No explanation, no markdown.

Required format:
{
  "sentiment_score": 0-10,
  "churn_risk": 0-100,
  "churn_signals": ["signal1", "signal2"]
}
```

**User Prompt:**
```
User rating: 3/10
Comment: "El servicio es muy malo, siempre se cae. Estoy pensando en cambiar a Tigo."
```

---

## 9. VALIDATION

### 9.1 Prompt Validation

```python
def validate_prompt_schema(prompt_file: str) -> ValidationResult:
    """Validate prompt YAML structure"""

    required_fields = ["module", "version", "variants", "output_schema"]
    required_variants = ["llama"]  # At minimum, local must work

    # ... validation logic
```

### 9.2 Interpolation Validation

```python
def validate_interpolation(
    template: str,
    language_pack: LanguagePack
) -> List[str]:
    """Find missing variables"""

    import re
    variables_in_template = re.findall(r'\{(\w+)\}', template)
    available_variables = language_pack.get_variable_names()

    missing = [v for v in variables_in_template if v not in available_variables]
    return missing
```

---

## SUMMARY

```
PROMPT SCHEMA APPROACH:
- Prompts stored as YAML configuration
- Model-family variants (llama, openai, anthropic)
- Language variables interpolated from Language Packs
- Modular: base + enabled modules assembled

ON-PREMISE FOCUS:
- llama family is default
- Simpler prompts for smaller models
- JSON-in-prompt format for models without structured output

CACHING:
- Stable prefix for prompt caching (OpenAI/Anthropic)
- Prompt hash tracked for cache invalidation

VERSIONING:
- Per-module version tracking
- Manifest with hashes
- Cache invalidation on prompt change
```

---

**Document Version:** 1.0.0
**Generated:** 2025-12-15
**Resolves:** Gap 2 (System Prompts)
**Stack Focus:** Arrow + Cloudflare + On-Premise (Local-First)
