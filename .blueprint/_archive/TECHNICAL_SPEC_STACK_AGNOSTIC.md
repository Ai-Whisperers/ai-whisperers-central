# Customer Feedback Analyzer - Stack-Agnostic Technical Specification

**Version:** 3.10.0
**Generated:** 2025-12-13
**Purpose:** Migration planning for Arrow+Ray+Redpanda architecture
**Source:** Complete codebase analysis (359 Python files)

---

## TABLE OF CONTENTS

1. [Data Processing Features](#1-data-processing-features)
2. [Analysis Features](#2-analysis-features)
3. [Caching Strategy](#3-caching-strategy)
4. [Export Features](#4-export-features)
5. [Pipeline Architecture](#5-pipeline-architecture)
6. [Domain Logic & Business Rules](#6-domain-logic--business-rules)
7. [Integration Points](#7-integration-points)
8. [Configuration Parameters](#8-configuration-parameters)
9. [Data Schemas](#9-data-schemas)

---

## 1. DATA PROCESSING FEATURES

### 1.1 Text Normalization

**Function:** Canonical text normalization for consistent analysis
**Location:** `/api/app/domain/feedback/duplicates/duplicate_detector.py:normalize_for_comparison()`

**Input:**
- Raw comment text (any encoding, whitespace variations)

**Output:**
- Normalized string (NFC Unicode, lowercase, single-spaced)

**Algorithm:**
```python
1. Apply Unicode NFC normalization (é, ñ, á as single characters)
2. Convert to lowercase
3. Strip leading/trailing whitespace
4. Collapse multiple spaces to single space
```

**Configuration:** None (deterministic)

**Performance:** ~5µs per comment (critical path - used by 40+ downstream modules)

**Optimization:** Pre-compute once, store in `Normalized_Comment` column for 10x speedup

---

### 1.2 Duplicate Detection

**Function:** Exact and near-duplicate detection with grouping
**Location:** `/api/app/domain/feedback/duplicates/duplicate_detector.py`

#### 1.2.1 Exact Duplicates

**Algorithm:**
```python
1. Normalize comment → canonical form
2. Calculate SHA256 hash (first 16 chars)
3. Group by hash
4. Count occurrences per hash
```

**Output Columns:**
- `Is Duplicate` (boolean)
- `Duplicate Count` (integer)
- `_comment_hash` (internal, 16-char hex)
- `Normalized_Comment` (canonical form, kept for downstream modules)

**Deduplication Savings:** Typically 15-20% reduction in API calls

#### 1.2.2 Near-Duplicates

**Algorithm:** O(n²) pairwise comparison with SequenceMatcher

**Parameters:**
- `similarity_threshold`: float (default: 0.95)

**Process:**
```python
1. For each comment i:
   2. Compare with all comments j (where j > i)
   3. Calculate similarity = SequenceMatcher(text_i, text_j).ratio()
   4. If similarity >= threshold:
      5. Assign to same group
   6. Track first occurrence per group
```

**Output Columns:**
- `Near Duplicate Group` (integer ID, -1 if unique)
- `Near Duplicate Similarity` (float, max similarity in group)
- `First Occurrence ID` (index of first in group)
- `Is First Occurrence` (boolean)

**Complexity:** O(n²) - only use on pre-filtered subsets

**Optimization:** Skip if `len(comment) < 5`

---

### 1.3 File Format Support

**Source:** `/api/app/config/file_formats.py`

#### Supported Upload Formats

| Format | Extension | Engine | Max Size |
|--------|-----------|--------|----------|
| CSV | `.csv` | pandas | 100 MB |
| TSV | `.tsv` | pandas | 100 MB |
| Excel (old) | `.xls` | xlrd | 100 MB |
| Excel (new) | `.xlsx` | openpyxl | 100 MB |
| Parquet | `.parquet` | pyarrow | 100 MB |

**Excel Row Limit:** 1,048,576 rows (Excel 2007+ spec)
**Excel Column Limit:** 16,384 columns (XFD)

#### Encoding Fallback Chain

**CSV/TSV Only:**
```python
1. UTF-8 (primary)
2. UTF-8-BOM
3. Latin-1 (Spanish-optimized)
4. ISO-8859-1
5. CP1252 (Windows Western European)
```

**Fallback Strategy:** Try each encoding sequentially until successful parse

---

### 1.4 Schema Detection & Validation

**Source:** `/api/app/config/analysis_thresholds.py:SchemaConfidenceThresholds`

**Required Columns (Minimum):**
- Rating column: `Nota` (0-10), `NPS`, or similar
- Comment column: `Comentario Final`, `Feedback`, `Comment`, or similar

**Optional Columns:**
- Customer demographics
- Service quality ratings
- Timestamps
- Customer IDs

#### Schema Confidence Scoring

**Thresholds (0.0 - 1.0):**
```python
HIGH_CONFIDENCE = 0.85  # Auto-approve
MEDIUM_CONFIDENCE = 0.70  # Production minimum
LOW_CONFIDENCE = 0.60  # Development acceptable
MINIMUM_ACCEPTABLE = 0.50  # Reject below this
```

**Confidence Calculation:**
```python
confidence = fuzzy_match_score(column_name, expected_name)
```

**Fuzzy Matching Thresholds (0-100):**
```python
STRICT = 85  # Schema detection
DEFAULT = 75  # Column name matching
LOOSE = 60  # Exploratory
MINIMUM = 50  # Absolute minimum
```

---

### 1.5 Word Count & Text Metrics

**Function:** Comment quality assessment
**Source:** Multiple modules use `len(comment.split())`

**Metrics:**
- `Word Count`: Number of words (split on whitespace)
- `Character Count`: Length of string

**Quality Thresholds:**
```python
TEXT_LENGTH_THRESHOLDS = {
    'very_short': 2,   # 1-2 words
    'short': 5,        # 3-5 words
    'medium': 20,      # 6-20 words
    'long': 50,        # 21-50 words
}

COMMENT_QUALITY_THRESHOLDS = {
    'min_word_count': 3,              # Minimum for valid analysis
    'generic_max_unique_words': 5,    # Max unique words for "generic" flag
    'spam_repetition_ratio': 0.5,     # Max ratio of repeated words
    'min_characters': 10,              # Minimum characters
}
```

**Analysis Tier Assignment (SIMPLIFIED v3.10.0):**
```python
# ALL comments receive FULL_AI tier (GPT-4o-mini)
# BASIC_AI and FREE tiers removed for consistent quality
ANALYSIS_TIER_THRESHOLDS = {
    'full_ai_min_words': 0  # No minimum - all comments analyzed
}
```

---

## 2. ANALYSIS FEATURES

### 2.1 Sentiment Analysis (Local Spanish NLP)

**Function:** Spanish lexicon-based sentiment scoring
**Source:** Domain-specific Spanish NLP (hybrid approach)

**Input:** Normalized comment text (Spanish)

**Output:**
- `Sentiment Score` (float, 0-10 scale)
- `Sentiment Category` ("Positive", "Neutral", "Negative")

**Algorithm:**
```python
1. Tokenize comment (word-level)
2. Lookup each word in Spanish lexicon
3. Apply modifiers:
   - Negation detection (flip polarity)
   - Intensifiers (boost 15%: "muy", "demasiado")
   - Sarcasm penalty (-15%)
   - Conditional mood reduction (-10%: "si", "si pudiera")
   - Temporal contrast penalty (-20%: "antes", "ahora")
4. Aggregate word scores → sentence score
5. Normalize to 0-10 scale
```

**Sentiment Adjustments:**
```python
SENTIMENT_ADJUSTMENTS = {
    'sarcasm_penalty': 0.85,       # -15%
    'negation_flip': 0.5,          # Subtract 50% of base score
    'intensifier_boost': 1.15,     # +15%
    'conditional_reduction': 0.9,   # -10%
    'temporal_complaint_penalty': 0.8,  # -20%
}
```

**Thresholds:**
```python
SENTIMENT_THRESHOLDS = {
    'positive_min': 7.0,   # >= 7.0 = Positive
    'neutral_min': 4.0,    # >= 4.0 and < 7.0 = Neutral
                           # < 4.0 = Negative
}
```

---

### 2.2 Emotion Detection (GPT-4o-mini)

**Function:** 7-category emotion classification
**Source:** `/api/app/domain/feedback/emotion_calculator.py`

**Emotion Categories:**
```python
POSITIVE_EMOTIONS = ["satisfaccion", "confianza", "anticipacion"]
NEGATIVE_EMOTIONS = ["frustracion", "enojo", "decepcion"]
NEUTRAL_EMOTIONS = ["confusion"]
```

**Input:** Comment text (Spanish)

**Output:**
```python
{
    "satisfaccion": 0.0-1.0,
    "confianza": 0.0-1.0,
    "anticipacion": 0.0-1.0,
    "frustracion": 0.0-1.0,
    "enojo": 0.0-1.0,
    "decepcion": 0.0-1.0,
    "confusion": 0.0-1.0
}
```

**Derived Metrics:**

#### Sentiment Score from Emotions
```python
positive = sum(satisfaccion, confianza, anticipacion)
negative = sum(frustracion, enojo, decepcion)
neutral = confusion
total = positive + negative + neutral

sentiment_score = (positive - negative) / total  # Range: -1.0 to +1.0
```

#### Dominant Emotion
```python
dominant_emotion = argmax(emotion_scores)
```

---

### 2.3 NPS Calculation

**Source:** `/api/app/domain/feedback/nps_calculator.py`

#### 2.3.1 NPS Category from Rating

**Input:** User rating (0-10)

**Thresholds:**
```python
NPS_THRESHOLDS = {
    'promoter_min': 9,   # 9-10 = Promoter
    'passive_min': 7,    # 7-8 = Passive
                          # 0-6 = Detractor
}
```

**Output:** `"promoter"`, `"passive"`, or `"detractor"`

#### 2.3.2 NPS Category from Emotions

**Used when explicit rating unavailable**

**Algorithm:**
```python
positive = sum(satisfaccion, confianza, anticipacion)
negative = sum(frustracion, enojo, decepcion)

if positive > 0.7 and negative < 0.3:
    return "promoter"
elif negative > 0.5:
    return "detractor"
else:
    return "passive"
```

**Thresholds:**
```python
NPS_PROMOTER_POSITIVE_THRESHOLD = 0.7
NPS_PROMOTER_NEGATIVE_MAX = 0.3
NPS_DETRACTOR_NEGATIVE_THRESHOLD = 0.5
```

#### 2.3.3 NPS Score Calculation

**Input:** Count of promoters, passives, detractors

**Formula (4 methods available):**

**SHIFTED (default):**
```python
base_score = (promoters - detractors) / total
shifted_score = (base_score + 1) * 50  # Range: 0-100
```

**STANDARD:**
```python
nps = (promoters - detractors) / total * 100  # Range: -100 to +100
```

**ABSOLUTE:**
```python
nps = abs((promoters - detractors) / total * 100)  # Always positive
```

**WEIGHTED:**
```python
passive_weight = 0.5  # Configurable
nps = (promoters - detractors + (passives * passive_weight)) / total * 100
```

**Configuration:** `NPS_CALCULATION_METHOD` env var

---

### 2.4 Churn Risk Calculation (Enhanced V2)

**Source:** `/api/app/domain/feedback/churn_risk/churn_calculator.py`

**Output:** 0-100 integer score with 4 risk levels

#### 2.4.1 Risk Levels

```python
CRITICAL: 80-100  # Immediate intervention (24-48h)
HIGH: 60-79       # Priority attention (1-3 days)
MEDIUM: 40-59     # Monitor and engage (within 1 week)
LOW: 0-39         # Standard monitoring
```

#### 2.4.2 Scoring Components

**Base Score from User Rating:**
```python
# Linear mapping: 0 → 100, 10 → 0
score_contribution = (10 - user_score) * 10
```

**Behavioral Signals:**
```python
'exit_threat': 30 points              # "cancelar", "dar de baja"
'exit_threat + competitor': +10 boost  # Combined threat
'competitor_mention': 15 points        # Named alternative
```

**Technical Signals:**
```python
'technical_failure': 15 points         # Service outage
'recurring_issue': 10 points           # Pattern of problems
```

**Economic Signals:**
```python
'cost_concern': 10 points
'cost_concern + exit': +5 boost
```

**Sentiment Signals:**
```python
'sentiment_misalignment': 5 points     # If alignment < 0.7
'high_emotion': 5 points               # Intense emotions
```

**Total Score:**
```python
total = base_score + behavioral + technical + economic + sentiment
total = clamp(total, 0, 100)
```

#### 2.4.3 Special Rules (Score Overrides)

```python
# RULE 1: Already churned (past tense detected)
patterns = [r'\b(decidí|cancelé|di de baja)\b']
if matched: score = max(score, 95)

# RULE 2: Imminent cancellation (timeline detected)
patterns = [r'\b(voy a cancelar|apenas pueda)\b']
if matched: score = max(score, 90)

# RULE 3: High score + exit threat
if user_score >= 7 and has_exit_threat:
    score = max(score, 85)

# RULE 4: Low score + technical failure
if user_score <= 3 and has_technical_failure:
    score = max(score, 75)

# RULE 5: Triple threat (exit + competitor + cost)
if has_exit_threat and has_competitor_mention and has_cost_concern:
    score = max(score, 90)

# RULE 6: Escalation pattern (recurring + exit)
if has_recurring_issue and has_exit_threat:
    score = int(score * 1.1)  # 10% boost
```

#### 2.4.4 Temporal Urgency Detection (NEW v2)

**Extracted from comment text:**

```python
TEMPORAL_URGENCY = {
    "ALREADY CHURNED": ["decidí cancelar", "ya cancelé", "di de baja"],
    "IMMEDIATE": ["ahora", "ya", "hoy", "inmediatamente"],
    "SHORT-TERM": ["pronto", "apenas", "cuando pueda"],
    "MEDIUM-TERM": ["considerar", "pensando", "buscando"]
}
```

**Output:** Urgency level string or None

#### 2.4.5 Competitor Intelligence Extraction (NEW v2)

**Detects:**
- Competitor names (Tigo, Claro, Copaco, Personal, Movistar, Vox, Nucleotel)
- Context (positive comparison, specific offer, returning customer, negative comparison)

**Output:**
```python
{
    "names": "Tigo, Claro",  # Comma-separated
    "context": "Tigo (positive comparison), Claro (specific offer)"
}
```

#### 2.4.6 Confidence Scoring (Clarity-Based)

**NOT word-count based - based on threat clarity:**

```python
confidence = 0.50  # Base

if has_exit_threat: confidence += 0.15
if has_competitor_mention: confidence += 0.10
if has_technical_failure: confidence += 0.10
if has_cost_concern: confidence += 0.10
if sentiment_alignment available: confidence += 0.05
if word_count >= 10: confidence += 0.05

confidence = clamp(confidence, 0.0, 1.0)
```

#### 2.4.7 Actionable Recommendations (NEW v2)

**Generated based on risk level + signals:**

```python
if CRITICAL:
    if has_competitor and has_cost:
        "Call within 24hrs. Offer price match. Escalate to retention manager."
    elif has_technical_failure:
        "Emergency technical support. Dispatch within 24hrs. Credit account."
    elif temporal_urgency == "ALREADY CHURNED":
        "Exit interview. Document reasons. Prevent similar losses."
    else:
        "Immediate supervisor callback. Authorize 30% retention discount."

elif HIGH:
    if has_exit_threat:
        "Contact within 48hrs. Assess issues. Retention team involvement."
    else:
        "Proactive outreach within 3 days. Document resolution."

elif MEDIUM:
    "Follow-up within 1 week. Monitor for escalation."

else:
    "Standard monitoring. Track pattern changes."
```

#### 2.4.8 Quality Gate

**Minimum requirements for reliable scoring:**

```python
QUALITY_GATES = {
    'min_word_count': 3,
    'exclude_generic': True,
    'exclude_gibberish': True
}
```

**If quality gate fails:** Return low-confidence result (score=0, confidence=0.0)

---

### 2.5 Pain Point Classification (21 Categories - Phase C)

**Source:** `/api/app/domain/feedback/pain_points/pain_point_classifier.py`

#### 2.5.1 Category Taxonomy

**Core Service Quality (6):**
- `CONNECTIVITY`: Connection drops, service outages
- `SPEED`: Slow internet, bandwidth issues
- `RELIABILITY`: Frequent failures, stability problems
- `COVERAGE`: Signal strength, geographic reach
- `LATENCY`: Lag, ping, delay
- `EQUIPMENT`: Router, modem, hardware issues

**Customer Experience (8):**
- `SATISFACTION`: General positive/negative feedback
- `SUPPORT_QUALITY`: Customer service quality
- `GENERAL_QUALITY`: Vague "improve service" comments
- `RESPONSE_TIME`: Slow support response
- `INSTALLATION`: Setup, activation issues
- `COMMUNICATION`: Lack of notifications, poor communication
- `ATTITUDE`: Staff behavior (positive or negative)

**Billing & Admin (4):**
- `BILLING`: Billing errors, double charges
- `PRICING`: Price complaints, cost concerns
- `PAYMENT`: Payment methods, discounts, promotions
- `CONTRACT`: Contract terms, plan changes

**Business Risk (4 - NEW Phase C):**
- `CHURN_INTENT`: Explicit cancellation intent
- `COMPETITIVE_PRESSURE`: Competitor mentions
- `FRAUD_CONCERN`: Fraud allegations
- `TRUST`: Broken promises, misleading advertising

**Catch-All (2):**
- `GENERIC`: Generic sentiment words
- `OTHER`: Unclassified

#### 2.5.2 Classification Algorithm

**Keyword-Based Multi-Label:**

```python
1. Normalize comment to lowercase
2. For each category:
   3. Count keyword matches using word boundary regex
   4. Score = total keyword matches
5. Sort categories by score (descending)
6. Select top categories above threshold

7. PRIORITY RULE: If PRICING and BILLING both matched:
   8. Boost PRICING score by 2x (price complaints > billing errors)

9. DEDUPLICATION RULES:
   10. SATISFACTION supersedes GENERAL_QUALITY
   11. Specific pain points supersede SUPPORT_QUALITY
   12. Remove GENERAL_QUALITY if 2+ other categories present

10. Return (primary, secondary, matched_keywords)
```

**Thresholds:**
```python
min_score_threshold = 2  # Minimum keyword matches to include category
```

#### 2.5.3 Keyword Extraction & Filtering

**Stop Words (Filtered from Keywords):**
```python
STOP_WORDS = {
    # Generic business terms
    "servicio", "empresa", "cliente", "usuario",
    # Common verbs/adjectives
    "tener", "hacer", "dar", "estar", "ser",
    # Articles
    "el", "la", "los", "las",
    # Generic quality terms
    "no", "nada", "bien", "mal", "bueno", "malo",
    # Overly generic
    "muy", "mucho", "más", "menos", "mejorar"
}
```

**Company Names (Flagged Separately, Not Keywords):**
```python
COMPANY_NAMES = {
    "personal", "tigo", "claro", "copaco", "vox", "nucleotel",
    "movistar", "entel", "oi", "vivo"
}
```

#### 2.5.4 Multi-Label Classification (Phase B)

**Unlike primary+secondary (max 2), returns ALL detected categories:**

```python
def classify_pain_points_multi_label(
    text,
    min_score_threshold=2
) -> (categories, keywords):
    """
    Returns:
        categories: ["CONNECTIVITY", "SPEED", "PRICING"]
        keywords: ["lento", "cae", "caro"]
    """
```

**Output Format:**
- `Pain_Points`: Comma-separated categories ("CONNECTIVITY,SPEED,PRICING")
- `Pain_Point_Keywords`: Comma-separated keywords

---

### 2.6 AI Score Correction (Discrepancy Resolution)

**Source:** `/api/app/domain/feedback/ai_score_corrector.py`

**Purpose:** Re-analyze comments where user rating and AI sentiment strongly disagree

**Trigger Condition:**
```python
abs(user_score - ai_sentiment) >= 5.0  # High discrepancy
```

**Process:**
```python
1. Filter high-discrepancy comments (gap >= 5.0)
2. Check persistent cache for existing corrections
3. For uncached:
   4. Send batch to GPT-4o-mini for re-analysis
   5. GPT investigates:
      - Sarcasm detection
      - Cultural context (Spanish-specific idioms)
      - Temporal contrast ("antes bueno, ahora malo")
      - Inverted scale detection
   6. Returns corrected score + explanation
7. Save to persistent cache
8. Add 5 columns to DataFrame:
   - ai_corrected_score
   - score_explanation
   - review_confidence (HIGH/MEDIUM/LOW)
   - needs_review (boolean)
   - detected_patterns (comma-separated)
```

**Cache Performance:**
- Hit rate: Typically 40-60% on second run (same dataset)
- Reduces API calls by 40-60%

---

### 2.7 Analysis Score Calculator (Intelligent Score Selection)

**Source:** `/api/app/domain/feedback/analysis_score.py`

**Purpose:** Select best score for analysis by considering user rating, AI sentiment, and their relationship

**Decision Tree:**

```python
# Case 1: No scores available
if user_score is None and ai_sentiment is None:
    return (None, "No data")

# Case 2: Only AI sentiment
if user_score is None and ai_sentiment is not None:
    return (ai_sentiment, "AI Sentiment (no user score)")

# Case 3: Only user score
if user_score is not None and ai_sentiment is None:
    return (user_score, "User (no AI analysis)")

# Case 4: Both available - calculate gap
gap = abs(user_score - ai_sentiment)

# Case 4a: Aligned (gap < 2.0)
if gap < 2.0:
    return (user_score, "User (validated by AI)")

# Case 4b: Moderate gap (2.0 <= gap < 5.0)
if gap < 5.0:
    return (user_score, "User (slight sentiment mismatch)")

# Case 4c: Large conflict (gap >= 5.0)
if gpt_corrected_score is not None:
    return (gpt_corrected_score, "GPT-4o (resolved conflict)")
else:
    return (user_score, f"User (conflict detected, gap={gap:.1f})")
```

**Thresholds:**
```python
ALIGNED_THRESHOLD = 2.0       # < 2.0 = aligned
CONFLICT_THRESHOLD = 5.0      # >= 5.0 = needs investigation
```

**Cost Optimization:**
```python
# Only investigate genuine conflicts (gap >= 5.0)
# Reduces GPT-4o API calls by 80-90%
```

---

### 2.8 Behavioral Flags Detection

**Source:** `/api/app/domain/feedback/behavioral_flags/flag_detector.py`

**Detects binary flags from comment text:**

#### Exit Threat
```python
patterns = [
    r'\b(cancelar|dar de baja|cambiar proveedor)\b',
    r'\b(pensando en cambiar|considero cambiar)\b',
    r'\b(busco otro proveedor|buscar alternativa)\b'
]
has_exit_threat = any(pattern.search(comment) for pattern in patterns)
```

#### Competitor Mention
```python
competitors = ["tigo", "claro", "personal", "copaco", "movistar"]
has_competitor = any(comp in comment.lower() for comp in competitors)
```

#### Technical Failure
```python
patterns = [
    r'\b(sin servicio|no funciona|caido|se cae)\b',
    r'\b(intermitente|cortes frecuentes)\b'
]
has_technical_failure = any(pattern.search(comment) for pattern in patterns)
```

#### Recurring Issue
```python
patterns = [
    r'\b(todos los dias|cada dia|siempre|frecuente)\b',
    r'\b(otra vez|de nuevo|constantemente)\b'
]
has_recurring_issue = any(pattern.search(comment) for pattern in patterns)
```

#### Cost Concern
```python
patterns = [
    r'\b(caro|costoso|precio alto|muy costoso)\b',
    r'\b(no puedo pagar|aumentar precio)\b'
]
has_cost_concern = any(pattern.search(comment) for pattern in patterns)
```

---

### 2.9 Metrics & Column Enrichment

**Source:** `/api/app/domain/feedback/metrics/calculated_metrics.py`

#### Sentiment Score Alignment

**Formula:**
```python
# How well AI sentiment matches user rating
# Both normalized to 0-1 scale
alignment = 1 - abs(user_score/10 - ai_sentiment/10)
```

**Range:** 0.0 (completely misaligned) to 1.0 (perfect alignment)

#### Actionability Score

**Measures how actionable a comment is:**

```python
score = 0.5  # Base

# Specificity indicators (+0.1 each)
if mentions_specific_issue: score += 0.1
if mentions_location: score += 0.1
if mentions_time: score += 0.1
if mentions_person: score += 0.1

# Detail indicators
if word_count > 20: score += 0.1

# Vagueness penalties (-0.1 each)
if too_generic: score -= 0.1
if sentiment_only: score -= 0.1

score = clamp(score, 0.0, 1.0)
```

**Output:** Float 0.0-1.0

#### Review Priority Score

**0-100 score for triage:**

```python
priority = 0

# User rating contribution (0-40 points)
if user_score <= 3: priority += 40
elif user_score <= 5: priority += 30
elif user_score <= 7: priority += 20

# Churn risk contribution (0-30 points)
if churn_risk >= 80: priority += 30
elif churn_risk >= 60: priority += 20
elif churn_risk >= 40: priority += 10

# Exit threat contribution (0-20 points)
if has_exit_threat: priority += 20

# Actionability contribution (0-10 points)
priority += int(actionability_score * 10)

priority = clamp(priority, 0, 100)
```

**Priority Levels:**
```python
URGENT: 80-100    # Review immediately
HIGH: 60-79       # Review within 24h
MEDIUM: 40-59     # Review within 3 days
LOW: 0-39         # Standard review
```

---

### 2.10 Deep Insights JSON Generation

**Source:** `/api/app/domain/feedback/insights/insights_generator.py`

**Simplified v3.10.0:** Only `FULL_AI` tier (BASIC_AI/FREE removed)

**Output Structure:**

```json
{
  "version": "1.0",
  "analysis_tier": "FULL_AI",
  "generated_at": "2025-12-13T10:30:00Z",

  "sentiment_analysis": {
    "primary_emotion": "frustracion",
    "emotion_intensity": 0.8,
    "sentiment_drivers": ["slow_speed", "frequent_outages"],
    "tone": "negative",
    "urgency_level": "high"
  },

  "pain_points": {
    "primary": {
      "category": "CONNECTIVITY",
      "description": "Connection drops daily",
      "severity": "high",
      "impact_score": 8
    },
    "secondary": [
      {
        "category": "SPEED",
        "severity": "medium",
        "impact_score": 6
      }
    ]
  },

  "churn_analysis": {
    "churn_risk": 85,
    "churn_factors": ["exit_threat", "technical_failure"],
    "churn_indicators": ["explicit_cancellation_intent"]
  },

  "improvement_suggestions": [
    "Improve network stability",
    "Faster technical support response"
  ],

  "keywords_extracted": ["conexion", "cae", "lento"],

  "quality_metrics": {
    "comment_specificity": 0.7,
    "actionability": 0.8,
    "clarity": 0.9,
    "completeness": 0.6
  },

  "patterns_detected": {
    "recurring_issue": true,
    "time_specific": false,
    "service_quality_mention": true,
    "competitor_mention": false,
    "price_sensitivity": false
  }
}
```

**OpenAI Data Fields (Optional):**
- All fields populated from GPT-4o-mini response
- If OpenAI call fails, uses fallback defaults

---

## 3. CACHING STRATEGY

### 3.1 Two-Tier Architecture

**Source:** `/api/app/infrastructure/cache/persistent_cache_manager.py`

**Tier 1: Redis (Hot Cache)**
- TTL: 7 days (configurable: `CACHE_TTL_DAYS`)
- Purpose: Fast access, session persistence
- Eviction: LRU after TTL expiry

**Tier 2: Filesystem (Cold Cache)**
- TTL: Permanent (configurable: `CACHE_RETENTION_DAYS=0` for forever)
- Purpose: Permanent storage, cost savings across restarts
- Location: `api/cache/ai_responses/{language}/{hash}.json`

### 3.2 Cache Key Generation

**Algorithm:**
```python
1. Normalize comment: lowercase + strip whitespace
2. Prepend language code: "es:{normalized_comment}"
3. Hash with SHA256
4. Take first 16 hex characters
5. Format: "analysis:cache:es:{hash16}"
```

**Example:**
```python
comment = "El servicio es MALO"
normalized = "el servicio es malo"
content = "es:el servicio es malo"
hash = SHA256(content)[:16]
key = "analysis:cache:es:a3f1b2c8d4e5f6a7"
```

### 3.3 Cache Schema Versioning

**Current Version:** `3.1`

**Versioning Strategy:**
- Increment on breaking schema changes
- Check version on retrieval
- Invalidate mismatched versions (force re-analysis)

**Schema Evolution:**
```
v1.0: Initial (emotions, churn_risk, pain_points)
v2.0: Added unified analysis fields
v3.0: Comprehensive AI structure
v3.1: Added impact_score, confidence_metrics
```

### 3.4 Cache Retrieval Process

```python
1. Check BYPASS_OPENAI_CACHE flag
   If True: Skip cache, force API call

2. Try Redis (hot cache):
   redis.get(key)
   If found: Return immediately (cache hit)

3. Try Filesystem (cold cache):
   read_file(cache_dir/language/hash.json)
   If found:
      Check schema version compatibility
      If mismatch: Invalidate, return None
      Update metadata (last_accessed, reuse_count)
      Warm up Redis with filesystem data
      Return cached analysis

4. Cache miss: Return None (will trigger API call)
```

### 3.5 Cache Storage Process

```python
1. Strip NPS category before caching
   (NPS always recomputed from rating for ground truth accuracy)

2. Save to Redis (hot cache):
   redis.setex(key, ttl_seconds, json.dumps(analysis))

3. Save to Filesystem (cold cache):
   file_path = cache_dir/language/hash.json
   cache_data = {
       "comment_hash": hash,
       "comment": comment,
       "language": language,
       "analysis": analysis,  # NPS category excluded
       "metadata": {
           "model": "gpt-4o-mini",
           "timestamp": utcnow(),
           "schema_version": "3.1",
           "cost_tokens_input": 1234,
           "cost_tokens_output": 567,
           "cached_reuse_count": 0,
           "created_at": utcnow(),
           "last_accessed": utcnow()
       }
   }
   write_file(file_path, cache_data)
```

### 3.6 Batch Operations

**get_many():**
```python
1. Check BYPASS flag
2. Try Redis batch (mget):
   keys = [get_cache_key(c) for c in comments]
   values = redis.mget(keys)
   Parse successful results
3. For uncached indices, try filesystem:
   Parallel file reads
   Warm up Redis with found entries
4. Return (cached_results_dict, uncached_indices_list)
```

**set_many():**
```python
1. Strip NPS categories from all analyses
2. Save to Redis (pipeline):
   pipe = redis.pipeline()
   for comment, analysis in results:
       pipe.setex(key, ttl, json.dumps(analysis))
   pipe.execute()
3. Save to filesystem (sequential):
   for comment, analysis in results:
       set(comment, analysis, language, metadata)
```

### 3.7 Cache Statistics

**Tracked Metrics:**
```python
{
    "redis_hits": int,
    "filesystem_hits": int,
    "total_hits": int,
    "misses": int,
    "errors": int,
    "saves": int,
    "total_requests": int,
    "hit_rate": float  # (redis_hits + fs_hits) / total
}
```

**Typical Performance:**
- First run: 0% hit rate
- Second run (same dataset): 40-60% hit rate (deduplication savings)
- Third run: 60-80% hit rate (filesystem persistence)

### 3.8 Cache Bypass Mode

**Configuration:** `BYPASS_OPENAI_CACHE=True`

**Behavior:**
- Skip cache retrieval (both Redis and filesystem)
- Force fresh OpenAI API calls
- Results still saved to cache for future use

**Use Case:** Testing new prompts, forcing re-analysis

---

### 3.9 Dataset-Level Caching

**Source:** `/api/app/infrastructure/cache/dataset_cache_manager.py`

**Purpose:** Cache entire dataset analysis results

**Key Format:**
```python
f"dataset:{file_hash}:analysis"
```

**Cached Data:**
```python
{
    "file_hash": "sha256_hash",
    "total_rows": 10000,
    "processed_rows": 10000,
    "timestamp": "2025-12-13T10:00:00Z",
    "results": {
        # Serialized DataFrame or summary
    }
}
```

**TTL:** 24 hours (configurable: `RESULTS_TTL_SECONDS`)

---

### 3.10 Schema Signature Caching

**Source:** `/api/app/application/pipeline/schema_signature_cache.py`

**Purpose:** Cache detected schema mappings

**Key Format:**
```python
f"schema:{column_fingerprint}"
```

**Cached Data:**
```python
{
    "rating_column": "Nota",
    "comment_column": "Comentario Final",
    "confidence": 0.92,
    "timestamp": "2025-12-13T10:00:00Z"
}
```

**Benefits:** Skip schema detection on repeated uploads of same format

---

## 4. EXPORT FEATURES

### 4.1 Google Sheets Export (ONLY Export Format v3.10.0)

**Source:** `/api/app/domain/export/google_drive/`

**Excel export removed - Google Sheets is the only supported export format**

#### 4.1.1 Authentication

**OAuth 2.0 Flow:**
```python
GOOGLE_AUTH_TYPE=oauth
GOOGLE_OAUTH_CLIENT_SECRET=/path/to/oauth-client-secret.json
GOOGLE_OAUTH_TOKEN=/path/to/oauth-token.pickle
```

**Required Scopes:**
- `https://www.googleapis.com/auth/spreadsheets` (Create/edit sheets)
- `https://www.googleapis.com/auth/drive.file` (Create files in Drive)

#### 4.1.2 Export Structure (4 Tabs)

**Tab 1: Dashboard (Executive Summary)**
- KPIs: Total reviews, NPS, average satisfaction
- Charts: NPS distribution, emotion breakdown, pain point categories
- High-priority review table (top 20 urgent items)
- Conditional formatting (red: urgent, yellow: high, green: medium)

**Tab 2: Alta Prioridad (High Priority)**
- Filtered rows: Review Priority Score >= 60
- Columns: Essential + churn risk details
- Sort: By Review Priority Score (descending)

**Tab 3: Análisis Comprimido (Compressed Analysis)**
- Essential columns only (12 core columns)
- All rows
- Daily review friendly

**Tab 4: Análisis Completo (Complete Analysis)**
- All 36 columns
- All rows
- Full dataset

#### 4.1.3 Column Schema (36 Columns, 6 Groups)

**GROUP 1: Primary Review Columns (10)**
```python
1. User Score (0-10)
2. Customer Comment (text)
3. AI Sentiment (0-10, Spanish NLP)
4. Analysis Score (intelligent selection)
5. Score Source (explanation)
6. Sentiment Category (Positive/Neutral/Negative)
7. Emotion (dominant)
8. Churn Risk (0-100)
9. Review Priority Score (0-100)
10. Pain Point Category (Primary)
```

**GROUP 2: Secondary Analysis Columns (7)**
```python
11. Pain Point Category (Secondary)
12. Pain Point Keywords
13. Sentiment Score Alignment (0-1)
14. Actionability Score (0-1)
15. Word Count
16. Has Deep Insights (boolean)
17. Deep Insights JSON (structured)
```

**GROUP 3: Duplicate Detection (5)**
```python
18. Is Duplicate (boolean)
19. Duplicate Count
20. Duplicate Group ID
21. First Occurrence ID
22. Is First Occurrence (boolean)
```

**GROUP 4: Quality Control (3)**
```python
23. Quality Flags (comma-separated)
24. Analysis Tier ("FULL_AI")
25. Problemas Detectados (issues)
```

**GROUP 5: AI Correction Details (4)**
```python
26. Original User Score
27. Sentiment Score (Before Discrepancy Check)
28. Discrepancy Flag (boolean)
29. Discrepancy Explanation
```

**GROUP 6: Technical Scores (2)**
```python
30. Sentiment Score (GPT-4o-mini)
31. Confidence Score (0-1)
```

**Churn Risk Extended (NEW v2 - 5 additional columns):**
```python
32. Churn Risk Temporal Urgency
33. Churn Risk Competitor
34. Churn Risk Competitor Context
35. Churn Risk Recommended Action
36. Churn Risk Reasoning
```

#### 4.1.4 Conditional Formatting

**Review Priority Score:**
```python
80-100: Red fill, white text (URGENT)
60-79: Yellow fill, black text (HIGH)
40-59: Green fill, black text (MEDIUM)
0-39: White fill, black text (LOW)
```

**Churn Risk:**
```python
80-100: Red fill (CRITICAL)
60-79: Orange fill (HIGH)
40-59: Yellow fill (MEDIUM)
0-39: Green fill (LOW)
```

**NPS Category:**
```python
Promoter: Green fill
Passive: Yellow fill
Detractor: Red fill
```

#### 4.1.5 API Endpoint

**POST `/api/export/google-sheets`**

**Request:**
```json
{
    "task_id": "abc123",
    "title": "Customer Feedback Analysis - December 2025"
}
```

**Response:**
```json
{
    "status": "success",
    "spreadsheet_id": "1a2b3c4d5e6f7g8h9i0j",
    "spreadsheet_url": "https://docs.google.com/spreadsheets/d/1a2b3c4d5e6f7g8h9i0j/edit",
    "tab_count": 4,
    "total_rows": 10000,
    "processing_time_seconds": 45.3
}
```

---

### 4.2 CSV Export

**Simple flat-file export:**

**Columns:** All 36 analysis columns

**Encoding:** UTF-8 with BOM (Excel compatibility)

**Endpoint:** `GET /api/export/csv/{task_id}`

---

## 5. PIPELINE ARCHITECTURE

### 5.1 Processing Stages

**Source:** Application pipeline modules (various)

#### Stage 1: Upload & Validation
```python
1. File upload (API endpoint)
2. File format validation (extension, size)
3. File reading (pandas with engine selection)
4. Schema detection (column mapping)
5. Preview generation (first 10 rows)
```

#### Stage 2: Pre-Processing
```python
6. Duplicate detection (exact + near-duplicate)
7. Text normalization (NFC, lowercase, single-space)
8. Word count calculation
9. Quality gate filtering (min 3 words, no gibberish)
```

#### Stage 3: AI Analysis (Batch Processing)
```python
10. Cache lookup (two-tier: Redis + filesystem)
11. Batch construction (150 comments/batch default)
12. OpenAI API calls (parallel workers: 6 default)
13. Response parsing & validation
14. Cache storage (both tiers)
```

#### Stage 4: Post-Processing
```python
15. Emotion calculation
16. NPS category assignment (from rating, not cached)
17. Churn risk calculation
18. Pain point classification
19. Behavioral flags detection
20. Metrics calculation
21. Deep insights JSON generation
```

#### Stage 5: Score Correction (Conditional)
```python
22. Discrepancy detection (gap >= 5.0)
23. GPT-4o re-analysis (cached)
24. Score override application
```

#### Stage 6: Export
```python
25. Column enrichment
26. Sorting/filtering (by priority)
27. Google Sheets generation (4 tabs)
28. Conditional formatting
29. URL return
```

---

### 5.2 Batch Processing Configuration

**Source:** `/api/app/config/settings.py`

```python
# Batch sizing (optimized for 8GB RAM)
BATCH_SIZE_OPTIMAL = 150        # Default batch size
MAX_BATCH_SIZE = 150            # Hard limit
MIN_BATCH_SIZE = 10             # Emergency minimum
EMERGENCY_BATCH_SIZE = 50       # Fallback under memory pressure

# Parallelism
OPENAI_CONCURRENT_WORKERS = 6   # Parallel API calls
ENABLE_PARALLEL_PROCESSING = True

# Memory management
MEMORY_WARNING_MB = 5000        # 5GB - trigger adaptive sizing
MEMORY_CRITICAL_MB = 6500       # 6.5GB - reject new tasks
DYNAMIC_BATCH_SIZING = True     # Auto-adjust based on memory
```

**Adaptive Batch Sizing:**
```python
if available_memory_mb < MEMORY_WARNING_MB:
    batch_size = max(MIN_BATCH_SIZE, batch_size // 2)
if available_memory_mb < MEMORY_CRITICAL_MB:
    batch_size = EMERGENCY_BATCH_SIZE
```

---

### 5.3 Deduplication Optimization

**Source:** `/api/app/application/pipeline/efficient_deduplication.py`

**Pre-Analysis Deduplication:**

```python
1. Calculate SHA256 hash for each comment
2. Group by hash
3. Create deduplication map:
   {
       unique_comment_1: [idx_1, idx_2, idx_5],
       unique_comment_2: [idx_3, idx_4]
   }
4. Send only unique comments to OpenAI
5. Broadcast results to all duplicate indices
```

**Savings:**
- Typical: 15-20% reduction in API calls
- Best case: 50%+ for highly repetitive datasets

---

### 5.4 Token Estimation

**Source:** `/api/app/application/pipeline/token_estimator.py`

**Pre-Analysis Cost Estimation:**

```python
def estimate_tokens(comment: str) -> int:
    """
    Rough estimate: ~0.75 tokens per word
    GPT-4o tokenizer: ~1.3 chars per token for Spanish
    """
    words = len(comment.split())
    return int(words * 0.75)

def estimate_batch_cost(comments: List[str]) -> dict:
    input_tokens = sum(estimate_tokens(c) for c in comments)
    output_tokens = len(comments) * 150  # Avg response ~150 tokens

    # GPT-4o-mini pricing (as of 2025)
    input_cost = input_tokens * 0.000000150   # $0.150 per 1M tokens
    output_cost = output_tokens * 0.000000600  # $0.600 per 1M tokens

    return {
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "estimated_cost_usd": input_cost + output_cost
    }
```

---

### 5.5 Parallel Batch Execution

**Source:** `/api/app/application/pipeline/parallel_batch_executor.py`

**Async Worker Pool:**

```python
async def process_batches_parallel(
    batches: List[List[str]],
    max_workers: int = 6
) -> List[dict]:
    """
    Process multiple batches in parallel.

    Uses asyncio.gather() with semaphore for rate limiting.
    """
    semaphore = asyncio.Semaphore(max_workers)

    async def process_with_limit(batch):
        async with semaphore:
            return await process_batch(batch)

    tasks = [process_with_limit(batch) for batch in batches]
    results = await asyncio.gather(*tasks)

    return results
```

**Rate Limiting:**
```python
MAX_RPS = 5  # 5 requests per second
# OpenAI TPM: 200,000 tokens/min = ~3,333 tokens/sec
# Safe margin for variable batch sizes
```

---

### 5.6 Audit Trail Logging

**Source:** `/api/app/application/pipeline/audit_trail_logger.py`

**Logged Events:**
```python
- Upload started (file size, row count, schema)
- Batch created (batch ID, comment count)
- API call made (model, tokens, latency)
- Cache hit/miss (key, tier)
- Analysis completed (duration, errors)
- Export generated (format, rows, size)
```

**Log Format:** Structured JSON (for ELK/Splunk ingestion)

---

## 6. DOMAIN LOGIC & BUSINESS RULES

### 6.1 Thresholds Reference

**All thresholds from:** `/api/app/config/analysis_thresholds.py`

**Sentiment:**
```python
POSITIVE_MIN = 7.0
NEUTRAL_MIN = 4.0
```

**NPS:**
```python
PROMOTER_MIN = 9
PASSIVE_MIN = 7
```

**Churn Risk:**
```python
HIGH_RISK_MAX = 3.0
MEDIUM_RISK_MAX = 5.0
```

**Review Priority:**
```python
URGENT = 80
HIGH = 60
MEDIUM = 40
```

**Discrepancy:**
```python
HIGH = 5.0
MEDIUM = 3.0
LOW = 1.5
```

**Confidence:**
```python
HIGH = 0.8
MEDIUM = 0.6
LOW = 0.4
```

**Similarity (Deduplication):**
```python
DUPLICATE_DETECTION = 0.95
NEAR_DUPLICATE = 0.85
SIMILAR_CONTENT = 0.70
```

---

### 6.2 Business Rules

#### Rule 1: NPS Category Never Cached

**Rationale:** Ground truth accuracy

**Implementation:**
```python
# Before caching
analysis_to_cache = analysis.copy()
analysis_to_cache.pop("nps_category", None)

# After retrieval
nps_category = calculate_nps_category(user_rating)
```

#### Rule 2: Consensus Scoring Deprecated

**Flag:** `ENABLE_CONSENSUS_SCORING = False`

**Rationale:** User rating and AI sentiment measure different things

**Current Approach:** Keep both as separate signals, use intelligent selection

#### Rule 3: Analysis Tier Simplified

**v3.10.0:** All comments receive `FULL_AI` tier (GPT-4o-mini)

**Removed:**
- `BASIC_AI` tier (word count 5-20)
- `FREE` tier (word count < 5)

**Rationale:** Consistent analysis quality, simplified codebase

#### Rule 4: Pricing Takes Priority Over Billing

**When both pain points detected:**
```python
if PRICING in categories and BILLING in categories:
    category_scores[PRICING] *= 2  # Boost PRICING
```

**Rationale:** Price complaints more common than billing errors

#### Rule 5: Churn Risk Quality Gate

**Minimum requirements:**
```python
word_count >= 3
not is_generic
not is_gibberish
```

**If fails:** Return low-confidence result (score=0, confidence=0.0)

---

## 7. INTEGRATION POINTS

### 7.1 OpenAI API (GPT-4o-mini)

**Endpoint:** `https://api.openai.com/v1/chat/completions`

**Configuration:**
```python
MODEL = "gpt-4o-mini"
TIMEOUT_SECONDS = 120
MAX_RETRIES = 3
BACKOFF_FACTOR = 2  # Exponential backoff
```

**Request Format:**
```json
{
    "model": "gpt-4o-mini",
    "messages": [
        {
            "role": "system",
            "content": "You are a Spanish customer feedback analyst..."
        },
        {
            "role": "user",
            "content": "Analyze these comments:\n1. {comment1}\n2. {comment2}"
        }
    ],
    "response_format": {
        "type": "json_schema",
        "json_schema": {
            "strict": true,
            "schema": {...}
        }
    },
    "temperature": 0.1
}
```

**Response Format:**
```json
{
    "id": "chatcmpl-abc123",
    "object": "chat.completion",
    "created": 1702483200,
    "model": "gpt-4o-mini-2024-07-18",
    "choices": [
        {
            "index": 0,
            "message": {
                "role": "assistant",
                "content": "{...structured JSON...}"
            },
            "finish_reason": "stop"
        }
    ],
    "usage": {
        "prompt_tokens": 1234,
        "completion_tokens": 567,
        "total_tokens": 1801
    }
}
```

**Rate Limits:**
```
TPM (Tokens Per Minute): 200,000
RPM (Requests Per Minute): 500
RPD (Requests Per Day): 10,000
```

**Cost (as of 2025):**
```
Input: $0.150 per 1M tokens
Output: $0.600 per 1M tokens
```

**Prompt Caching (Enabled):**
```
50% cost savings on input tokens for cached system prompts
```

---

### 7.2 Redis

**Purpose:**
- Hot cache (Tier 1)
- Celery broker/backend
- Task result storage

**Connection:**
```python
REDIS_URL = "redis://localhost:6379/0"
```

**Libraries:**
- `redis-py` (production)
- `fakeredis` (testing: `USE_FAKE_REDIS=true`)

**Key Patterns:**
```python
# Analysis cache
"analysis:cache:{language}:{hash16}"

# Dataset cache
"dataset:{file_hash}:analysis"

# Schema cache
"schema:{column_fingerprint}"

# Task results
"celery-task-meta-{task_id}"
```

**TTL:**
```python
CACHE_TTL_DAYS = 7  # Analysis cache
RESULTS_TTL_SECONDS = 86400  # 24 hours
FILE_CONTENT_TTL_SECONDS = 3600  # 1 hour
```

---

### 7.3 Google Sheets API

**Endpoint:** `https://sheets.googleapis.com/v4/spreadsheets`

**Authentication:** OAuth 2.0

**Scopes:**
```
https://www.googleapis.com/auth/spreadsheets
https://www.googleapis.com/auth/drive.file
```

**Operations:**
```python
# Create spreadsheet
POST /v4/spreadsheets
{
    "properties": {
        "title": "Customer Feedback Analysis"
    },
    "sheets": [...]
}

# Update values
PUT /v4/spreadsheets/{spreadsheetId}/values/{range}
{
    "values": [[...]]
}

# Batch update (formatting)
POST /v4/spreadsheets/{spreadsheetId}:batchUpdate
{
    "requests": [...]
}
```

**Timeout:** 300 seconds (5 minutes)

**Rate Limits:**
```
Read: 100 requests per 100 seconds per user
Write: 100 requests per 100 seconds per user
```

---

### 7.4 Celery Task Queue

**Broker:** Redis

**Backend:** Redis

**Configuration:**
```python
CELERY_BROKER_URL = "redis://localhost:6379/0"
CELERY_RESULT_BACKEND = "redis://localhost:6379/0"
CELERY_WORKER_CONCURRENCY = 4
```

**Task Routing:**
```python
# Analysis task
@celery.task(name="analyze_feedback")
def analyze_feedback_task(file_path, task_id):
    ...

# Export task
@celery.task(name="export_to_google_sheets")
def export_task(task_id, title):
    ...
```

**Status Monitoring:**
```python
GET /api/task-status/{task_id}

Response:
{
    "status": "PROCESSING",
    "progress": 65,
    "total_rows": 10000,
    "processed_rows": 6500,
    "estimated_time_remaining_seconds": 120
}
```

---

## 8. CONFIGURATION PARAMETERS

### 8.1 Environment Variables

**Complete reference from `/api/app/config/settings.py`**

#### Application
```python
APP_ENV = "development"              # Environment
DEBUG = True                         # Debug mode
SECRET_KEY = "..."                   # Min 32 chars
PORT = 8000                          # API port
```

#### OpenAI
```python
OPENAI_API_KEY = ""                  # Required
AI_MODEL = "gpt-4o-mini"             # Model selection
OPENAI_TIMEOUT_SECONDS = 120         # API timeout
ENABLE_PROMPT_CACHING = True         # 50% input token savings
```

#### Redis
```python
REDIS_URL = "redis://localhost:6379/0"
USE_FAKE_REDIS = False               # Testing only
```

#### Batch Processing
```python
BATCH_SIZE_OPTIMAL = 150             # Default batch size
MAX_BATCH_SIZE = 150                 # Hard limit
MIN_BATCH_SIZE = 10                  # Minimum
EMERGENCY_BATCH_SIZE = 50            # Under memory pressure
OPENAI_CONCURRENT_WORKERS = 6        # Parallel workers
ENABLE_PARALLEL_PROCESSING = True    # Enable async
```

#### Memory Management
```python
MEMORY_WARNING_MB = 5000             # 5GB warning
MEMORY_CRITICAL_MB = 6500            # 6.5GB critical
DYNAMIC_BATCH_SIZING = True          # Auto-adjust
```

#### Caching
```python
ENABLE_COMMENT_CACHE = True          # Redis cache
CACHE_TTL_DAYS = 7                   # TTL in days
BYPASS_OPENAI_CACHE = False          # Force fresh API calls

ENABLE_PERSISTENT_CACHE = True       # Filesystem cache
PERSISTENT_CACHE_DIR = "api/cache"   # Cache directory
CACHE_RETENTION_DAYS = 0             # 0 = keep forever
CACHE_TO_REPO = False                # Don't commit cache
```

#### Google Sheets
```python
GOOGLE_SHEETS_ENABLED = True
GOOGLE_SHEETS_TAB_COUNT = 4
GOOGLE_SHEETS_TIMEOUT_SECONDS = 300
GOOGLE_SHEETS_ENABLE_FORMATTING = True
```

#### File Processing
```python
FILE_MAX_MB = 20                     # Max upload size
RESULTS_TTL_SECONDS = 86400          # 24 hours
FILE_CONTENT_TTL_SECONDS = 3600      # 1 hour
```

#### Performance
```python
MAX_RPS = 5                          # Rate limiting
LOG_PERFORMANCE_METRICS = True       # Enable metrics
ALERT_THRESHOLD_SECONDS = 15         # Alert if >15s
```

---

### 8.2 Feature Flags

```python
# Analysis
ENABLE_CONSENSUS_SCORING = False     # Deprecated (keep separate signals)
HYBRID_ANALYSIS_ENABLED = True       # Local + OpenAI hybrid

# Caching
BYPASS_OPENAI_CACHE = False          # Force fresh API calls
ENABLE_PERSISTENT_CACHE = True       # Filesystem cache
CACHE_TO_REPO = False                # Don't commit cache

# Processing
ENABLE_PARALLEL_PROCESSING = True    # Async batch processing
DYNAMIC_BATCH_SIZING = True          # Auto-adjust batch size

# Export
GOOGLE_SHEETS_ENABLED = True         # Only export format (v3.10.0)
GOOGLE_SHEETS_ENABLE_FORMATTING = True

# Monitoring
LOG_PERFORMANCE_METRICS = True       # Log timing
```

---

## 9. DATA SCHEMAS

### 9.1 Input Schema (Minimum Required)

**Required Columns:**
```python
rating: 0-10 integer or float
comment: string (text feedback)
```

**Optional Columns:**
```python
customer_id: string
timestamp: datetime
demographics: dict
service_ratings: dict
```

**Flexible Column Names:**
```python
# Rating column
"Nota", "NPS", "Rating", "Score", "Puntuacion"

# Comment column
"Comentario Final", "Feedback", "Comment", "Review", "Comentario del Cliente"
```

---

### 9.2 Analysis Output Schema (36 Columns)

**PRIMARY (10):**
```python
1. User Score: float (0-10)
2. Customer Comment: string
3. AI Sentiment: float (0-10)
4. Analysis Score: float (0-10, intelligent selection)
5. Score Source: string (explanation)
6. Sentiment Category: enum("Positive", "Neutral", "Negative")
7. Emotion: string (dominant emotion)
8. Churn Risk: int (0-100)
9. Review Priority Score: int (0-100)
10. Pain Point Category (Primary): string
```

**SECONDARY (7):**
```python
11. Pain Point Category (Secondary): string
12. Pain Point Keywords: string (comma-separated)
13. Sentiment Score Alignment: float (0-1)
14. Actionability Score: float (0-1)
15. Word Count: int
16. Has Deep Insights: bool
17. Deep Insights JSON: json_string
```

**DUPLICATES (5):**
```python
18. Is Duplicate: bool
19. Duplicate Count: int
20. Duplicate Group ID: int (-1 if unique)
21. First Occurrence ID: int
22. Is First Occurrence: bool
```

**QUALITY (3):**
```python
23. Quality Flags: string (comma-separated)
24. Analysis Tier: enum("FULL_AI")
25. Problemas Detectados: string
```

**AI CORRECTION (4):**
```python
26. Original User Score: float
27. Sentiment Score (Before Discrepancy Check): float
28. Discrepancy Flag: bool
29. Discrepancy Explanation: string
```

**TECHNICAL (2):**
```python
30. Sentiment Score (GPT-4o-mini): float
31. Confidence Score: float (0-1)
```

**CHURN EXTENDED (5 - NEW v2):**
```python
32. Churn Risk Temporal Urgency: string
33. Churn Risk Competitor: string
34. Churn Risk Competitor Context: string
35. Churn Risk Recommended Action: string
36. Churn Risk Reasoning: string
```

---

### 9.3 Cache Data Schema

**Filesystem Cache (v3.1):**
```json
{
    "comment_hash": "a3f1b2c8d4e5f6a7",
    "comment": "El servicio es malo",
    "language": "es",
    "analysis": {
        "emotion": "frustracion",
        "emotion_intensity": 0.7,
        "sentiment_score": 2.5,
        "churn_risk": 75,
        "pain_points": {...},
        "keywords": [...],
        "patterns": {...}
        // NOTE: nps_category excluded (recomputed from rating)
    },
    "metadata": {
        "model": "gpt-4o-mini",
        "timestamp": "2025-12-13T10:00:00Z",
        "schema_version": "3.1",
        "cost_tokens_input": 1234,
        "cost_tokens_output": 567,
        "cached_reuse_count": 0,
        "created_at": "2025-12-13T10:00:00Z",
        "last_accessed": "2025-12-13T10:05:00Z"
    }
}
```

---

### 9.4 API Response Schemas

**Upload Response:**
```json
{
    "status": "success",
    "task_id": "abc123",
    "file_hash": "sha256_hash",
    "total_rows": 10000,
    "schema_detected": {
        "rating_column": "Nota",
        "comment_column": "Comentario Final",
        "confidence": 0.92
    },
    "preview": [
        {"Nota": 8, "Comentario Final": "Buen servicio"},
        ...
    ],
    "estimated_cost_usd": 0.45,
    "estimated_time_seconds": 180
}
```

**Task Status Response:**
```json
{
    "status": "PROCESSING",
    "progress": 65,
    "total_rows": 10000,
    "processed_rows": 6500,
    "elapsed_seconds": 120,
    "estimated_time_remaining_seconds": 60,
    "cache_hit_rate": 0.45,
    "errors": []
}
```

**Export Response:**
```json
{
    "status": "success",
    "spreadsheet_id": "1a2b3c4d5e6f7g8h9i0j",
    "spreadsheet_url": "https://docs.google.com/spreadsheets/d/...",
    "tab_count": 4,
    "total_rows": 10000,
    "processing_time_seconds": 45.3
}
```

---

## APPENDIX A: Performance Benchmarks

**System:** 8GB RAM, 4-core CPU

**Dataset:** 10,000 comments, 15% duplicates

**Metrics:**
```
Upload & Schema Detection: 2.5 seconds
Deduplication: 8.5 seconds
Text Normalization: 3.2 seconds
Cache Lookup (Redis): 1.2 seconds
Cache Lookup (Filesystem): 4.8 seconds
OpenAI API Calls (150 batches, 6 parallel): 180 seconds
Post-Processing (all metrics): 12.5 seconds
Google Sheets Export (4 tabs): 45 seconds
TOTAL: ~4.5 minutes

Cache Hit Rate (second run): 55% (deduplication + repeat uploads)
Cost: ~$0.45 (without cache), ~$0.20 (with cache)
```

---

## APPENDIX B: Migration Considerations

### For Arrow+Ray+Redpanda Architecture:

**Data Processing (Arrow):**
- Replace pandas DataFrames with PyArrow Tables
- Use Arrow IPC for zero-copy data sharing
- Maintain all normalization algorithms (stack-agnostic)

**Distributed Processing (Ray):**
- Replace Celery workers with Ray actors
- Maintain batch processing logic
- Preserve parallel execution patterns

**Event Streaming (Redpanda):**
- Replace Redis pub/sub with Redpanda topics
- Maintain cache key structure (compatible with any KV store)
- Preserve two-tier caching strategy

**Business Logic:**
- All domain logic is stack-agnostic (pure Python functions)
- All thresholds/configuration can be ported directly
- All algorithms (sentiment, churn, pain points) remain unchanged

**Critical Path Optimizations:**
- Pre-compute `Normalized_Comment` column (10x speedup preserved)
- Deduplication strategy works with any data structure
- Cache schema versioning translates to any storage

---

## APPENDIX C: Cost Optimization Summary

**Total Cost Reduction: 87% vs Traditional Solutions**

**Breakdown:**
1. GPT-4o-mini (95% cheaper than GPT-4)
2. Deduplication (15-20% API call reduction)
3. Two-tier caching (40-60% hit rate on repeat)
4. Batch processing (minimize overhead)
5. Prompt caching (50% input token savings)
6. Smart score selection (80-90% fewer correction calls)

**Typical Cost:**
- First run (10K comments): $0.45
- Second run (55% cache hit): $0.20
- Third run (75% cache hit): $0.11

**Token Efficiency:**
- 25-30 tokens/comment (vs 250 before optimization)
- Batch overhead: ~200 tokens/batch
- Average response: ~150 tokens/comment

---

**END OF TECHNICAL SPECIFICATION**

**Document Version:** 1.0
**Generated:** 2025-12-13
**Source Files Analyzed:** 359 Python files
**Total Lines of Code:** ~75,000
**Critical Path Modules:** 48

---

## APPENDIX D: LOCAL-FIRST LLM ARCHITECTURE (2025-12-15)

### D.1 Section 7.1 Update: OpenAI is One Adapter Among Many

Section 7.1 (OpenAI API) describes the cloud-first implementation. This appendix documents the local-first architecture that supersedes it.

#### D.1.1 Provider Hierarchy (Updated)

**Original (Section 7.1):** OpenAI as primary, no local option.

**Updated:**
```
Priority 1-9: LOCAL PROVIDERS (Zero Cost)
├── Ollama        → http://localhost:11434 (default)
├── vLLM          → http://localhost:8000
├── llama.cpp     → http://localhost:8080
└── LM Studio     → http://localhost:1234

Priority 10+: CLOUD PROVIDERS (Pay-per-use)
├── OpenAI        → https://api.openai.com
├── Anthropic     → https://api.anthropic.com
├── Google        → https://generativelanguage.googleapis.com
└── Groq/Together → Various endpoints
```

#### D.1.2 Default Configuration Change

**Original (Section 7.1):**
```python
MODEL = "gpt-4o-mini"
ENDPOINT = "https://api.openai.com/v1/chat/completions"
```

**Updated:**
```python
# Default: Local Ollama (works offline, zero cost)
DEFAULT_PROVIDER = "ollama"
DEFAULT_MODEL = "llama3:8b"
DEFAULT_ENDPOINT = "http://localhost:11434/v1/chat/completions"

# Cloud fallback (opt-in via environment)
OPENAI_ENABLED = "${OPENAI_ENABLED:-false}"
ANTHROPIC_ENABLED = "${ANTHROPIC_ENABLED:-false}"
```

#### D.1.3 Batch Processing Update

**Original (Section 5.2):**
```python
BATCH_SIZE_OPTIMAL = 150
OPENAI_CONCURRENT_WORKERS = 6
```

**Updated (Provider-Aware):**
```python
BATCH_SIZE = {
    "ollama_7b": 10,       # Memory-bound
    "ollama_13b": 5,
    "vllm": 50,            # Continuous batching
    "openai": 50,          # Rate-limit-bound
    "anthropic": 30,
}

CONCURRENT_WORKERS = {
    "local": 1,            # Single GPU typically
    "cloud": 6,            # API can handle parallel
}
```

### D.2 Local Provider Configurations

#### D.2.1 Ollama (Default)

```python
OLLAMA_CONFIG = {
    "host": "${OLLAMA_HOST:-localhost}",
    "port": "${OLLAMA_PORT:-11434}",
    "model": "${OLLAMA_MODEL:-llama3:8b}",
    "context_size": 8192,
    "supports_structured_output": True,  # Ollama 0.5+
    "api_compatibility": "openai",       # OpenAI-compatible API
}
```

**Startup Check:**
```python
async def ensure_ollama_ready():
    """Verify Ollama is running and model is loaded"""
    try:
        response = await httpx.get("http://localhost:11434/api/tags")
        models = response.json().get("models", [])
        if not any(m["name"].startswith("llama3") for m in models):
            # Pull model if not present
            await httpx.post("http://localhost:11434/api/pull",
                           json={"name": "llama3:8b"})
        return True
    except:
        return False
```

#### D.2.2 vLLM (High-Throughput)

```python
VLLM_CONFIG = {
    "host": "${VLLM_HOST:-localhost}",
    "port": "${VLLM_PORT:-8000}",
    "model": "${VLLM_MODEL:-meta-llama/Llama-3-8B-Instruct}",
    "tensor_parallel_size": 1,           # GPUs for model parallelism
    "supports_structured_output": True,  # Guided decoding
    "supports_prefix_caching": True,     # Prompt caching
    "api_compatibility": "openai",
}
```

### D.3 Routing Strategy Integration

#### D.3.1 LLMRouter (New Component)

```python
class LLMRouter:
    """
    Routes requests to providers based on strategy.

    NOT part of batch processing pipeline (Section 5).
    Sits between BatchOrchestrator and ILLMProvider.
    """

    strategies = {
        "local_first": route_local_then_cloud,
        "cost": route_by_lowest_cost,
        "latency": route_by_lowest_latency,
        "quality": route_by_best_model,
        "failover": route_by_priority_chain,
    }

    async def get_provider(self, request: AnalysisRequest) -> ILLMProvider:
        healthy = await self._get_healthy_providers()
        strategy_fn = self.strategies[self.config.strategy]
        return strategy_fn(healthy, request)
```

#### D.3.2 Integration with Section 5 Pipeline

```
Section 5 Pipeline (unchanged):
Upload → Validation → Pre-Processing → [AI Analysis] → Post-Processing → Export

AI Analysis Stage (updated):
┌─────────────────────────────────────────────────────────┐
│ BatchOrchestrator                                       │
│   │                                                     │
│   ├── Cache Check (Section 3)                          │
│   │                                                     │
│   ├── LLMRouter.get_provider()  ← NEW                  │
│   │       │                                             │
│   │       ├── Ollama (local, priority 1)               │
│   │       ├── vLLM (local, priority 2)                 │
│   │       ├── OpenAI (cloud, priority 10)              │
│   │       └── Anthropic (cloud, priority 11)           │
│   │                                                     │
│   └── provider.analyze_batch()                         │
└─────────────────────────────────────────────────────────┘
```

### D.4 Cost Model Update

#### D.4.1 Section 7.1 Cost Update

**Original:**
```
Input: $0.150 per 1M tokens
Output: $0.600 per 1M tokens
```

**Updated (Multi-Provider):**
```
LOCAL PROVIDERS:
├── Ollama:    $0.00 (electricity only)
├── vLLM:      $0.00 (electricity only)
└── llama.cpp: $0.00 (electricity only)

CLOUD PROVIDERS:
├── OpenAI gpt-4o-mini:     $0.15/$0.60 per 1M tokens
├── OpenAI gpt-4o:          $2.50/$10.00 per 1M tokens
├── Anthropic Haiku:        $0.25/$1.25 per 1M tokens
├── Anthropic Sonnet:       $3.00/$15.00 per 1M tokens
├── Groq Llama3-70b:        $0.59/$0.79 per 1M tokens
└── Together Llama3-8b:     $0.20/$0.20 per 1M tokens
```

#### D.4.2 Cost Optimization Strategy

```python
# With local-first, typical cost breakdown:
# - 95% of requests: Local (Ollama) → $0.00
# - 5% of requests: Cloud fallback → Pay-per-use

# Example: 10,000 comments
# Original (cloud-only): ~$0.45
# Updated (local-first): ~$0.02 (only edge cases hit cloud)
```

### D.5 Section 3 Cache Integration

Cache key generation remains unchanged. Cache works across all providers:

```python
def generate_cache_key(comment: str, language: str) -> str:
    """
    Provider-agnostic cache key.
    Same comment returns same key regardless of provider.
    """
    normalized = normalize_text(comment)
    content = f"{language}:{normalized}"
    return hashlib.sha256(content.encode()).hexdigest()[:16]
```

**Cache Behavior:**
- First request: Miss → Route to provider → Cache result
- Second request: Hit → Return cached → No provider call
- Provider change: Still hits cache (key is content-based, not provider-based)

### D.6 Health Check Integration

```python
# Added to startup sequence
async def startup_health_check():
    """Check provider availability on startup"""

    providers = {
        "ollama": "http://localhost:11434/api/tags",
        "vllm": "http://localhost:8000/health",
        "openai": "https://api.openai.com/v1/models",
    }

    healthy = []
    for name, endpoint in providers.items():
        try:
            response = await httpx.get(endpoint, timeout=5.0)
            if response.status_code == 200:
                healthy.append(name)
        except:
            pass

    if not healthy:
        raise NoProviderAvailableError(
            "No LLM providers available. "
            "Start Ollama with: ollama serve"
        )

    return healthy
```

### D.7 Cross-Reference

| Topic | Authoritative Source |
|-------|---------------------|
| Interface specification | `LLM_PROVIDER_CONTRACT.md` |
| Adapter implementations | `LLM_PROVIDER_CONTRACT.md` Section 2 |
| Routing strategies | `LLM_PROVIDER_CONTRACT.md` Section 3 |
| Arrow integration | `LLM_PROVIDER_CONTRACT.md` Section 6 |
| Original OpenAI spec | This document, Section 7.1 (historical) |
