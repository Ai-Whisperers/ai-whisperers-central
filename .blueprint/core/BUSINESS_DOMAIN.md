# Feedback-Arrow: Business Features & Domain Logic

A comprehensive specification of business features, domain logic, and business rules—implemented in Rust with Apache Arrow as the core data format.

---

## Table of Contents

### Business Logic
1. [Product Overview](#1-product-overview)
2. [Core Business Capabilities](#2-core-business-capabilities)
3. [Feedback Analysis Domain](#3-feedback-analysis-domain)
4. [Emotion Detection System](#4-emotion-detection-system)
5. [Churn Risk Assessment](#5-churn-risk-assessment)
6. [Pain Point Classification](#6-pain-point-classification)
7. [NPS Calculation & Classification](#7-nps-calculation--classification)
8. [Score Alignment & Conflict Resolution](#8-score-alignment--conflict-resolution)
9. [Data Quality & Validation](#9-data-quality--validation)
10. [Document Generation](#10-document-generation)
11. [Export & Reporting](#11-export--reporting)
12. [Cost Management & Budget Control](#12-cost-management--budget-control)
13. [Caching & Optimization](#13-caching--optimization)
14. [Business Rules Reference](#14-business-rules-reference)
15. [Metrics & KPIs](#15-metrics--kpis)

### Reference Appendices
- [Appendix A: Emotion Reference](#appendix-a-emotion-reference)
- [Appendix B: Pain Point Categories Detail](#appendix-b-pain-point-categories-detail)

### Technical Implementation
- [Appendix C: Core Stack & Architecture](#appendix-c-core-stack--architecture)
- [Appendix D: Vendor-Agnostic Abstractions](#appendix-d-vendor-agnostic-abstractions)
- [Appendix E: Deployment](#appendix-e-deployment)

---

## 1. Product Overview

### 1.1 Product Definition

A SaaS application that analyzes customer feedback to extract actionable business intelligence using AI-powered natural language processing.

### 1.2 Core Value Proposition

| Capability | Business Value |
|------------|----------------|
| Emotion Detection | Understand HOW customers feel (16 emotions) |
| Churn Risk Scoring | Predict WHO is about to leave (0-100 scale) |
| Pain Point Classification | Identify WHAT issues matter most (21 categories) |
| NPS Analysis | Measure customer loyalty trends |
| Actionable Insights | Generate specific retention actions |

### 1.3 Target Use Cases

1. **Customer Success Teams** - Identify at-risk customers before they churn
2. **Product Teams** - Discover recurring pain points for prioritization
3. **Support Teams** - Route high-urgency feedback for immediate action
4. **Executive Leadership** - Monitor NPS trends and customer sentiment

---

## 2. Core Business Capabilities

### 2.1 Capability Map

```
FEEDBACK INGESTION
  |-- File Upload (CSV, Excel, Parquet)
  |-- Schema Detection (auto-mapping columns)
  |-- Data Validation (quality gates)
  |-- Cost Estimation (before processing)

FEEDBACK ANALYSIS
  |-- Emotion Detection (16 emotions)
  |-- Sentiment Scoring (-1 to +1)
  |-- Pain Point Classification (21 categories)
  |-- Churn Risk Calculation (0-100)
  |-- NPS Classification (Promoter/Passive/Detractor)

INSIGHT GENERATION
  |-- Score Alignment Detection
  |-- Conflict Resolution (user vs AI scores)
  |-- Review Priority Scoring
  |-- Temporal Urgency Detection
  |-- Competitor Intelligence Extraction

REPORTING & EXPORT
  |-- Executive Summaries (AI-generated)
  |-- Action Items & Recommendations
  |-- Specialized Spreadsheet Tabs
  |-- High-Priority Item Filtering

COST MANAGEMENT
  |-- Budget Enforcement (daily/monthly)
  |-- Intelligent Sampling (cost reduction)
  |-- Dataset Caching (100% savings on repeats)
  |-- Duplicate Detection (avoid reprocessing)
```

### 2.2 Processing Pipeline

```
Phase 1: INGESTION
  Upload -> Validate -> Detect Schema -> Estimate Cost -> Store

Phase 2: PREPARATION
  Load -> Deduplicate -> Sample (if large) -> Detect Language

Phase 3: ANALYSIS
  Extract Emotions -> Calculate Sentiment -> Classify Pain Points
  -> Score Churn Risk -> Categorize NPS -> Resolve Conflicts

Phase 4: FINALIZATION
  Aggregate Results -> Generate Insights -> Create Reports
  -> Export to Spreadsheet -> Notify User
```

---

## 3. Feedback Analysis Domain

### 3.1 Domain Model

**Core Entities:**

| Entity | Description | Key Attributes |
|--------|-------------|----------------|
| Feedback Comment | Single customer feedback item | text, rating, timestamp, customer_id |
| Analysis Result | AI-generated analysis | emotions, sentiment, pain_points, churn_risk |
| Analysis Task | Processing job | status, progress, results, metadata |
| Customer Segment | Grouping by NPS | promoter, passive, detractor |

**Value Objects:**

| Value Object | Description | Immutable Properties |
|--------------|-------------|---------------------|
| Emotion Profile | 16 emotion scores | each 0.0 to 1.0 |
| Sentiment Score | Overall sentiment | -1.0 to +1.0 |
| Churn Risk | Churn probability | score (0-100), level, factors |
| NPS Category | Loyalty classification | promoter, passive, detractor |
| Pain Point | Issue classification | category, severity, keywords |

### 3.2 Analysis Strategies

The system supports multiple analysis modes:

| Strategy | Description | Output |
|----------|-------------|--------|
| Comprehensive | Full 7-emotion + pain points | Complete analysis |
| Basic | Simple sentiment + NPS | Lightweight analysis |
| Deep Insights | Structured insights generation | Strategic recommendations |
| Discrepancy Resolution | Score conflict investigation | Corrected scores |

### 3.3 Aggregation Logic

Results are aggregated at multiple levels:

1. **Per-Comment** - Individual feedback analysis
2. **Per-Segment** - Aggregated by NPS category
3. **Per-Category** - Aggregated by pain point type
4. **Overall** - Complete dataset summary

---

## 4. Emotion Detection System

### 4.1 Emotion Taxonomy

The system detects 16 emotions organized into categories:

**Positive Emotions:**
| Emotion | Spanish | Description |
|---------|---------|-------------|
| Satisfaction | satisfaccion | Content with service/product |
| Trust | confianza | Believes in company reliability |
| Anticipation | anticipacion | Hopeful about future interactions |
| Joy | alegria | Happy with experience |
| Gratitude | gratitud | Thankful for service |

**Negative Emotions:**
| Emotion | Spanish | Description |
|---------|---------|-------------|
| Frustration | frustracion | Blocked from achieving goal |
| Anger | enojo | Actively upset |
| Disappointment | decepcion | Expectations not met |
| Sadness | tristeza | Unhappy with outcome |
| Fear | miedo | Worried about service/future |
| Disgust | disgusto | Strong aversion |

**Neutral/Complex Emotions:**
| Emotion | Spanish | Description |
|---------|---------|-------------|
| Confusion | confusion | Unclear about situation |
| Surprise | sorpresa | Unexpected experience |
| Neutral | neutral | No strong emotion |
| Concern | preocupacion | Worried but not fearful |
| Resignation | resignacion | Accepted negative outcome |

### 4.2 Emotion Scoring

Each emotion is scored on a 0.0 to 1.0 probability scale:

| Score Range | Interpretation |
|-------------|----------------|
| 0.0 - 0.2 | Not present |
| 0.2 - 0.4 | Slight presence |
| 0.4 - 0.6 | Moderate presence |
| 0.6 - 0.8 | Strong presence |
| 0.8 - 1.0 | Dominant emotion |

### 4.3 Sentiment Calculation from Emotions

The overall sentiment score is derived from emotion composition:

```
SENTIMENT FORMULA:
  positive_weight = sum(satisfaccion, confianza, anticipacion, alegria, gratitud)
  negative_weight = sum(frustracion, enojo, decepcion, tristeza, miedo, disgusto)

  sentiment = (positive_weight - negative_weight) / total_weight

  Result: -1.0 (extremely negative) to +1.0 (extremely positive)
```

### 4.4 Sentiment Classification Thresholds

| Level | Score Range | Business Meaning |
|-------|-------------|------------------|
| Positive | 7.0 - 10.0 | Favorable feedback, likely promoter |
| Neutral | 4.0 - 6.9 | Mixed or unclear sentiment |
| Negative | 0.0 - 3.9 | Critical feedback, churn risk |

---

## 5. Churn Risk Assessment

### 5.1 Churn Risk Model

The churn calculator uses a multifactorial scoring approach:

**Input Signals:**

| Signal | Weight | Description |
|--------|--------|-------------|
| User Score | High | NPS rating (0-10) |
| Exit Threat | Very High | Explicit cancellation language |
| Competitor Mention | High | References to competing services |
| Technical Failure | High | Reports of service issues |
| Recurring Issue | Medium | Repeated complaints |
| Cost Concern | Medium | Price sensitivity signals |
| Sentiment Alignment | Low | Gap between user/AI scores |
| High Emotion | Low | Intensity of negative emotions |

### 5.2 Churn Risk Tiers

| Tier | Score Range | Business Action |
|------|-------------|-----------------|
| CRITICAL | 95 - 100 | Immediate executive escalation |
| HIGH | 85 - 94 | Same-day retention outreach |
| MEDIUM | 60 - 84 | Proactive support follow-up |
| LOW | 0 - 59 | Standard monitoring |

### 5.3 Granular Scoring Ranges

For high-risk customers, granular ranges provide precision:

| Range | Interpretation |
|-------|----------------|
| 95 - 100 | Imminent churn (days) |
| 90 - 95 | Very high risk (1-2 weeks) |
| 85 - 90 | High risk (2-4 weeks) |
| 75 - 85 | Elevated risk (1-2 months) |

### 5.4 Temporal Urgency Classification

| Urgency | Indicators | Response Window |
|---------|------------|-----------------|
| IMMEDIATE | Exit threat, billing escalation | Hours |
| SHORT-TERM | Recurring technical issues | Days |
| MEDIUM-TERM | Support dissatisfaction | Weeks |
| ALREADY CHURNED | Past-tense complaints | Recovery attempt |

### 5.5 Competitor Intelligence

The system extracts competitor mentions and context:

**Tracked Competitors (Telecom Example):**
- Tigo, Claro, Movistar, Personal, WOM, ETB

**Extracted Fields:**
- `competitor_mentioned`: Name of competitor
- `competitor_context`: How they were mentioned (switching to, comparing, etc.)
- `recommended_action`: Specific retention action based on context

### 5.6 Churn Risk Output

Each analyzed comment produces:

```
CHURN RISK RESULT:
  score: 0-100 (integer)
  level: CRITICAL | HIGH | MEDIUM | LOW
  breakdown: {
    user_score_component: 0-40
    signal_component: 0-30
    sentiment_component: 0-20
    quality_component: 0-10
  }
  confidence: 0.0-1.0
  primary_factors: [list of top 3 risk drivers]
  temporal_urgency: IMMEDIATE | SHORT-TERM | MEDIUM-TERM | ALREADY_CHURNED
  competitor_mentioned: string | null
  recommended_action: specific retention action
```

---

## 6. Pain Point Classification

### 6.1 Pain Point Taxonomy

21 categories organized into business domains:

**Core Service Issues (6 categories):**

| Category | Keywords (Spanish) | Business Impact |
|----------|-------------------|-----------------|
| CONNECTIVITY | conexion, red, wifi, internet | Service availability |
| SPEED | velocidad, lento, rapido, mbps | Performance |
| RELIABILITY | estable, intermitente, caidas | Service quality |
| COVERAGE | cobertura, senal, zona | Geographic reach |
| LATENCY | demora, lag, ping, tiempo | Real-time performance |
| EQUIPMENT | modem, router, decodificador | Hardware issues |

**Customer Experience Issues (8 categories):**

| Category | Keywords (Spanish) | Business Impact |
|----------|-------------------|-----------------|
| SATISFACTION | contento, feliz, molesto | Overall experience |
| SUPPORT_QUALITY | atencion, servicio, ayuda | Support effectiveness |
| GENERAL_QUALITY | calidad, malo, bueno | Perception |
| RESPONSE_TIME | espera, tardaron, respuesta | Service speed |
| INSTALLATION | instalacion, tecnico, visita | Onboarding |
| COMMUNICATION | informacion, aviso, notificacion | Transparency |
| ATTITUDE | amable, grosero, profesional | Staff behavior |

**Billing & Administrative (4 categories):**

| Category | Keywords (Spanish) | Business Impact |
|----------|-------------------|-----------------|
| BILLING | factura, cobro, cargo | Financial accuracy |
| PRICING | precio, caro, barato, costo | Value perception |
| PAYMENT | pago, debito, tarjeta | Transaction issues |
| CONTRACT | contrato, permanencia, clausula | Terms & conditions |

**Business Risk Indicators (4 categories):**

| Category | Keywords (Spanish) | Business Impact |
|----------|-------------------|-----------------|
| CHURN_INTENT | cancelar, retirar, terminar | Explicit exit signals |
| COMPETITIVE_PRESSURE | competencia, otra empresa | Market pressure |
| FRAUD_CONCERN | fraude, estafa, engano | Trust issues |
| TRUST | confianza, credibilidad | Relationship health |

**Catch-All (2 categories):**

| Category | Description |
|----------|-------------|
| GENERIC | Non-specific feedback |
| OTHER | Unclassified issues |

### 6.2 Keyword Matching System

The classifier uses 200+ Spanish keywords with:

- **Primary Match**: Direct keyword detection
- **Secondary Match**: Contextual inference
- **Stop Word Filtering**: 40+ generic terms excluded
- **Company Name Filtering**: Competitor names filtered from categorization

### 6.3 Pain Point Output

```
PAIN POINT RESULT:
  primary_category: CONNECTIVITY
  secondary_categories: [SUPPORT_QUALITY, RESPONSE_TIME]
  keywords_matched: [conexion, lento, espera]
  severity: HIGH | MEDIUM | LOW
  actionable: true | false
```

---

## 7. NPS Calculation & Classification

### 7.1 NPS Categories

Based on the standard 0-10 rating scale:

| Category | Score Range | Definition |
|----------|-------------|------------|
| Promoter | 9 - 10 | Loyal enthusiasts who promote the brand |
| Passive | 7 - 8 | Satisfied but unenthusiastic |
| Detractor | 0 - 6 | Unhappy customers who may damage brand |

### 7.2 NPS Calculation Methods

The system supports 4 calculation methods:

**Method 1: STANDARD**
```
NPS = ((Promoters - Detractors) / Total) x 100
Range: -100 to +100
```

**Method 2: ABSOLUTE**
```
NPS = |((Promoters - Detractors) / Total) x 100|
Range: 0 to 100
```

**Method 3: WEIGHTED**
```
NPS = ((Promoters - Detractors + (Passives x weight)) / Total) x 100
Range: Variable (includes passive contribution)
```

**Method 4: SHIFTED**
```
NPS = (((Promoters - Detractors) / Total) + 1) x 50
Range: 0 to 100 (shifted from -100..+100)
```

### 7.3 NPS Score Interpretation

| Score Range | Interpretation | Industry Benchmark |
|-------------|----------------|-------------------|
| 70 - 100 | Excellent | Top performers |
| 50 - 69 | Great | Above average |
| 30 - 49 | Good | Average |
| 0 - 29 | Needs Improvement | Below average |
| -100 - -1 | Critical | Immediate action required |

### 7.4 NPS Metrics Output

```
NPS METRICS:
  score: -100 to +100
  promoter_count: integer
  passive_count: integer
  detractor_count: integer
  promoter_percentage: 0-100
  passive_percentage: 0-100
  detractor_percentage: 0-100
  calculation_method: STANDARD | ABSOLUTE | WEIGHTED | SHIFTED
  interpretation: string (business meaning)
```

---

## 8. Score Alignment & Conflict Resolution

### 8.1 Score Alignment Detection

The system compares user-provided ratings with AI-detected sentiment:

**Alignment Levels:**

| Level | Gap | Interpretation |
|-------|-----|----------------|
| ALIGNED | < 2.0 | User and AI agree |
| MODERATE | 2.0 - 4.9 | Minor discrepancy |
| CONFLICT | >= 5.0 | Major discrepancy requiring investigation |

### 8.2 Score Selection Logic

When both user rating and AI sentiment exist:

```
IF gap < 2.0:
  USE user_score  # AI validates user rating

ELSE IF gap < 5.0:
  USE user_score  # Customer intent is primary signal

ELSE IF gap >= 5.0:
  IF ai_investigation_available:
    USE ai_corrected_score  # Investigated conflict
  ELSE:
    USE user_score  # Fallback to customer
```

### 8.3 Conflict Investigation

For conflicts (gap >= 5.0), the system:

1. Sends comment for deeper AI analysis
2. Examines context and tone
3. Considers cultural/linguistic factors
4. Returns corrected score with explanation

**Cost Optimization:**
- Only 10-20% of comments require investigation
- 80-90% cost savings by detecting aligned scores early

### 8.4 Inverted Scale Detection

The system flags suspicious patterns:

| Pattern | Detection | Action |
|---------|-----------|--------|
| Positive text + Low score | sentiment >= 7.0 AND score <= 2 | Flag for manual review |
| Negative text + High score | sentiment < 4.0 AND score >= 9 | Flag for manual review |

---

## 9. Data Quality & Validation

### 9.1 File Validation Rules

| Rule | Constraint | Error Code |
|------|------------|------------|
| File Size | Max 100 MB | INVALID_FILE_SIZE |
| File Format | CSV, Excel, Parquet | INVALID_FILE_FORMAT |
| Required Columns | Score + Comment | MISSING_COLUMNS |
| Minimum Rows | At least 1 valid | NO_VALID_DATA |
| Empty Check | Non-empty DataFrame | EMPTY_FILE |

### 9.2 Column Detection

**Auto-Detection Patterns:**

| Column Type | Spanish Patterns | English Patterns |
|-------------|-----------------|------------------|
| Score | calificacion, puntuacion, nota, nps | rating, score, nps |
| Comment | comentario, feedback, opinion | comment, feedback, review |
| Date | fecha, creacion | date, created |
| Customer | cliente, cuenta | customer, account |

**Confidence Scoring:**
- Confidence >= 0.7 required for auto-detection
- Methods: Name pattern matching, value analysis, hybrid

### 9.3 Text Quality Assessment

| Quality Level | Word Count | Actionability |
|---------------|------------|---------------|
| Very Short | 1-2 words | Low |
| Short | 3-5 words | Moderate |
| Medium | 6-20 words | Good |
| Long | 21-50 words | High |
| Very Long | 50+ words | Maximum |

### 9.4 Comment Validation

| Check | Minimum | Effect |
|-------|---------|--------|
| Word Count | 3 words | Below = low confidence |
| Character Count | 10 chars | Below = may be gibberish |
| Generic Detection | Pattern match | Flagged as non-actionable |
| Gibberish Detection | Coherence score | Flagged as unusable |

### 9.5 Duplicate Detection

**Exact Duplicates:**
- SHA256 hash-based detection
- Text normalization: Unicode, lowercase, trim whitespace

**Near-Duplicates:**
- 95% similarity threshold
- Sequence matching algorithm
- Groups mapped to original

**Duplicate Handling:**
- Analyze original only
- Expand results to duplicates
- Preserves individual NPS ratings

---

## 10. Document Generation

### 10.1 Document Types

The system generates 4 AI-powered documents:

| Document | Audience | Content |
|----------|----------|---------|
| Executive Summary | C-level stakeholders | Statistical KPIs, trends, risks |
| Action Items | Team leads | Prioritized recommendations |
| Key Insights | Product managers | Patterns, opportunities |
| Methodology | Technical teams | Analysis approach, glossary |

### 10.2 Data Optimization for Generation

To reduce AI token usage (50-96% savings):

1. **Statistical Aggregation** - Summarize counts, averages, distributions
2. **Representative Sampling** - Select diverse examples
3. **Column Selection** - Include only relevant fields
4. **Content Enrichment** - Pre-compute derived metrics

### 10.3 Generation Pipeline

```
1. Validate input data
2. Hash data for caching
3. Check AI cache (avoid regeneration)
4. Process through optimization pipeline
5. Build prompt (language/tone/audience aware)
6. Validate prompt completeness
7. Generate with AI (structured output)
8. Parse and validate response
9. Format for output format
10. Cache response for reuse
11. Calculate generation metrics
```

### 10.4 Document Output

```
GENERATION RESULT:
  success: true | false
  document_url: link to generated document
  document_type: executive_summary | action_items | key_insights | methodology
  metrics: {
    tokens_used: integer
    generation_time_seconds: float
    cache_hit: boolean
    quality_score: 0-1
  }
```

---

## 11. Export & Reporting

### 11.1 Export Formats

| Format | Description | Use Case |
|--------|-------------|----------|
| Spreadsheet | 4 specialized tabs | Primary delivery |
| CSV | Raw data export | Data analysis |
| JSON | Structured data | API integration |

### 11.2 Spreadsheet Tabs

**Tab 1: Dashboard**
- Executive KPIs
- NPS summary chart
- Emotion distribution
- Churn risk overview
- Pain point frequency

**Tab 2: High Priority (Alta Prioridad)**
- Filter: Churn Risk >= 60% OR Review Priority >= 70%
- Columns: Customer, Rating, Risk, Urgency, Action
- Sorted by urgency

**Tab 3: Compressed Analysis (Analisis Comprimido)**
- Essential columns with hyperlinks
- Quick reference view
- Navigation to full details

**Tab 4: Complete Analysis (Analisis Completo)**
- All available columns
- 100+ metrics per row
- Full emotion profiles
- Complete pain point classification

### 11.3 Export Metrics

```
EXPORT RESULT:
  success: true | false
  url: link to exported file
  tabs_created: [list of tab names]
  rows_exported: integer
  columns_per_tab: {tab_name: column_count}
  processing_time_seconds: float
```

---

## 12. Cost Management & Budget Control

### 12.1 Budget Enforcement

The system enforces spending limits:

| Limit Type | Scope | Action When Exceeded |
|------------|-------|---------------------|
| Daily Budget | Per calendar day (UTC) | Reject new uploads |
| Monthly Budget | Per calendar month (UTC) | Reject new uploads |
| Token Safe Limit | Per upload | Reject individual upload |

### 12.2 Cost Estimation

Before processing, the system estimates:

```
COST ESTIMATE:
  total_comments: integer
  estimated_tokens: integer
  estimated_cost_usd: float
  within_budget: true | false
  remaining_daily_budget: float
  remaining_monthly_budget: float
```

### 12.3 Cost Optimization Strategies

| Strategy | Savings | Description |
|----------|---------|-------------|
| Dataset Caching | 100% | Skip reprocessing identical datasets |
| Duplicate Detection | Variable | Analyze originals only |
| Intelligent Sampling | Up to 90% | Sample large datasets |
| Score Alignment | 80-90% | Skip conflict investigation for aligned scores |
| Batch Processing | 50% | Use batch API pricing |

### 12.4 Spend Tracking

```
BUDGET STATUS:
  budget_enforcement_enabled: true | false
  daily: {
    limit_usd: float
    spent_usd: float
    remaining_usd: float
    percentage_used: 0-100
  }
  monthly: {
    limit_usd: float
    spent_usd: float
    remaining_usd: float
    percentage_used: 0-100
  }
  cost_per_comment_estimate_usd: float
```

---

## 13. Caching & Optimization

### 13.1 Cache Layers

| Cache Type | Key | TTL | Savings |
|------------|-----|-----|---------|
| Dataset Cache | SHA256 of comments + ratings | 7-30 days | 100% |
| Batch Cache | Per 50-comment batch | 7 days | Partial |
| Schema Cache | File structure signature | 30 days | Schema detection time |
| AI Response Cache | Data hash + prompt version | Configurable | Document regeneration |

### 13.2 Dataset Caching Logic

```
ON UPLOAD:
  1. Extract comments and ratings
  2. Calculate SHA256 checksum
  3. Check cache for matching checksum

  IF CACHE HIT:
    Return cached results immediately
    Log: 100% cost savings

  IF CACHE MISS:
    Process normally
    Store results with checksum key
```

### 13.3 Intelligent Sampling

For large datasets (> threshold):

```
SAMPLING STRATEGY:
  1. Calculate NPS distribution
  2. Set target sample size
  3. Stratify by NPS category:
     - Ensure minimum per category
     - Maintain proportional representation
  4. Select representative samples
  5. Analyze sample
  6. Extrapolate to full dataset
```

**Sampling Parameters:**
- Trigger threshold: Configurable (e.g., 10,000 rows)
- Target size: Configurable (e.g., 1,500 rows)
- Minimum per category: Configurable (e.g., 50)

### 13.4 Duplicate Optimization

```
DEDUPLICATION FLOW:
  1. Normalize all comments (unicode, lowercase, trim)
  2. Calculate SHA256 hashes
  3. Group duplicates by hash
  4. Detect near-duplicates (95% similarity)
  5. Analyze unique comments only
  6. Expand results to duplicates
  7. Preserve individual ratings for NPS
```

---

## 14. Business Rules Reference

### 14.1 Scoring Thresholds

| Metric | Threshold | Classification |
|--------|-----------|----------------|
| Sentiment Positive | >= 7.0 | Favorable |
| Sentiment Neutral | 4.0 - 6.9 | Mixed |
| Sentiment Negative | < 4.0 | Critical |
| NPS Promoter | 9 - 10 | Loyal |
| NPS Passive | 7 - 8 | At risk |
| NPS Detractor | 0 - 6 | Unhappy |
| Churn Critical | >= 95 | Immediate action |
| Churn High | 85 - 94 | Same-day action |
| Churn Medium | 60 - 84 | Proactive outreach |
| Score Conflict | gap >= 5.0 | Requires investigation |

### 14.2 Priority Scoring

| Priority Level | Score Range | Response SLA |
|----------------|-------------|--------------|
| URGENT | >= 80 | Immediate |
| HIGH | 60 - 79 | Within 24 hours |
| MEDIUM | 40 - 59 | Within 3 days |
| LOW | < 40 | Routine |

### 14.3 Confidence Scoring

| Confidence Level | Score Range | Reliability |
|------------------|-------------|-------------|
| High | >= 0.8 | Highly reliable |
| Medium | 0.6 - 0.79 | Moderately reliable |
| Low | 0.4 - 0.59 | Use with caution |
| Very Low | < 0.4 | Unreliable |

### 14.4 Actionability Scoring

Calculated from multiple factors:

```
ACTIONABILITY FORMULA:
  Base: Word count bonus (0-4)
  + Quality flags penalty (-2 per flag)
  + Pain point bonus (+2 if detected)
  + Emotion intensity bonus (+1 if high)
  + Specificity bonus (+2 if details present)

  Result: 0-10 scale
```

---

## 15. Metrics & KPIs

### 15.1 Analysis Metrics

| Metric | Description | Aggregation |
|--------|-------------|-------------|
| NPS Score | Net Promoter Score | Overall and by segment |
| Avg Sentiment | Mean sentiment score | Overall and by category |
| Avg Churn Risk | Mean churn probability | Overall and by segment |
| High Risk Count | Customers with churn >= 85 | Count |
| Pain Point Distribution | Issues by category | Frequency and percentage |
| Emotion Profile | Emotion averages | Per emotion type |

### 15.2 Operational Metrics

| Metric | Description | Purpose |
|--------|-------------|---------|
| Processing Time | Seconds to complete | Performance |
| Tokens Used | AI tokens consumed | Cost tracking |
| Cache Hit Rate | Percentage of cached results | Efficiency |
| Sampling Rate | Percentage sampled | Cost optimization |
| Duplicate Rate | Percentage of duplicates | Data quality |

### 15.3 Strategic Insights

The system generates SLA-auditable KPIs:

```
STRATEGIC MOVE:
  category: Pain point category
  priority: CRITICAL | HIGH | MEDIUM | LOW
  affected_customers: Count
  churn_risk_reduction: Potential improvement (0-1)
  recommended_action: Specific business action
  estimated_impact: Expected outcome (e.g., "15% churn reduction")
  kpi_metrics: Measurable success metrics
```

### 15.4 Dashboard KPIs

| KPI | Visualization | Update Frequency |
|-----|---------------|------------------|
| NPS Trend | Line chart | Per analysis |
| Churn Distribution | Pie chart | Per analysis |
| Pain Point Frequency | Bar chart | Per analysis |
| Emotion Heatmap | Heatmap | Per analysis |
| Sentiment by Category | Grouped bar | Per analysis |
| Priority Queue | Sorted list | Real-time |

---

## Appendix A: Emotion Reference

| Emotion (EN) | Emotion (ES) | Polarity | Weight |
|--------------|--------------|----------|--------|
| Satisfaction | satisfaccion | Positive | 1.0 |
| Trust | confianza | Positive | 1.0 |
| Anticipation | anticipacion | Positive | 0.8 |
| Joy | alegria | Positive | 1.0 |
| Gratitude | gratitud | Positive | 0.9 |
| Frustration | frustracion | Negative | 1.0 |
| Anger | enojo | Negative | 1.2 |
| Disappointment | decepcion | Negative | 1.0 |
| Sadness | tristeza | Negative | 0.8 |
| Fear | miedo | Negative | 0.9 |
| Disgust | disgusto | Negative | 1.1 |
| Confusion | confusion | Neutral | 0.0 |
| Surprise | sorpresa | Neutral | 0.0 |
| Neutral | neutral | Neutral | 0.0 |
| Concern | preocupacion | Negative | 0.5 |
| Resignation | resignacion | Negative | 0.7 |

---

## Appendix B: Pain Point Categories Detail

| ID | Category | Spanish Keywords (Sample) |
|----|----------|---------------------------|
| 1 | CONNECTIVITY | conexion, red, wifi, internet, desconecta |
| 2 | SPEED | velocidad, lento, rapido, mbps, megas |
| 3 | RELIABILITY | estable, intermitente, caidas, fallas |
| 4 | COVERAGE | cobertura, senal, zona, area |
| 5 | LATENCY | demora, lag, ping, tiempo |
| 6 | EQUIPMENT | modem, router, decodificador, equipo |
| 7 | SATISFACTION | contento, feliz, satisfecho, molesto |
| 8 | SUPPORT_QUALITY | atencion, servicio, ayuda, soporte |
| 9 | GENERAL_QUALITY | calidad, malo, bueno, pesimo |
| 10 | RESPONSE_TIME | espera, tardaron, respuesta, demora |
| 11 | INSTALLATION | instalacion, tecnico, visita, instalar |
| 12 | COMMUNICATION | informacion, aviso, notificacion |
| 13 | ATTITUDE | amable, grosero, profesional, descortes |
| 14 | BILLING | factura, cobro, cargo, recibo |
| 15 | PRICING | precio, caro, barato, costo, tarifa |
| 16 | PAYMENT | pago, debito, tarjeta, transferencia |
| 17 | CONTRACT | contrato, permanencia, clausula, terminos |
| 18 | CHURN_INTENT | cancelar, retirar, terminar, cambiar |
| 19 | COMPETITIVE_PRESSURE | competencia, otra empresa, mejor opcion |
| 20 | FRAUD_CONCERN | fraude, estafa, engano, robo |
| 21 | TRUST | confianza, credibilidad, mentira |

---

---

## Appendix C: Core Stack & Architecture

### C.1 Technology Stack

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| Language | Rust | 1.75+ | Memory safety, compile-time error detection |
| Data Format | Apache Arrow | 53 | Zero-copy columnar data, universal interchange |
| Storage | Parquet | 53 | Compressed columnar storage (zstd) |
| Query Engine | DataFusion | 43 | SQL support, query optimization |
| Debug/SQL | DuckDB | 1 | Ad-hoc queries, observability |
| Async Runtime | Tokio | 1.41 | Async I/O, task scheduling |
| HTTP Client | Reqwest | 0.12 | LLM API calls (rustls TLS) |
| HTTP Server | Axum | 0.7 | REST API, tower middleware |
| Serialization | Serde | 1 | JSON/TOML parsing |
| Error Handling | thiserror | 2 | Typed error codes (FA-XXX-NNN) |

### C.2 Crate Architecture

```
feedback-arrow/
├── Cargo.toml                    # Workspace root
├── crates/
│   ├── fa-core/                  # Traits + types + errors
│   │   ├── traits/               # LLMProvider, ComputeNode, StateStore, SecretStore
│   │   ├── types/                # AnalysisRequest, AnalysisResult, TenantContext
│   │   └── errors/               # FA-XXX-NNN error codes
│   ├── fa-pipeline/              # DAG executor + nodes
│   │   ├── graph/                # Topological sort, parallel execution
│   │   ├── nodes/                # 15 compute nodes (source, transform, enrich, llm, sink)
│   │   └── llm/                  # LlamaServerAdapter, OpenAIAdapter, AnthropicAdapter
│   ├── fa-storage/               # Persistence + caching
│   │   ├── cache/                # In-memory LRU, Redis adapter
│   │   └── persistence/          # DuckDB, PostgreSQL adapters
│   ├── fa-server/                # REST API
│   │   ├── routes/               # /api/v1/tasks, /api/v1/health
│   │   └── middleware/           # Auth, rate-limiting, tenant context
│   └── fa-cli/                   # Binary entry point
└── language_packs/               # JSON resources (es.json, en.json)
```

### C.3 Data Flow

```
Input (CSV/Excel/Parquet/JSON)
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Arrow RecordBatch                         │
│  (Zero-copy columnar format, shared across all nodes)       │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│                    DAG Executor                              │
│  ┌──────────┐   ┌───────────┐   ┌──────────────────────┐   │
│  │ Normalize│──▶│ Dedupe    │──▶│ Analysis (parallel)  │   │
│  └──────────┘   └───────────┘   │ Sentiment│Churn│NPS  │   │
│                                  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│              Enriched Arrow Table (36 columns)               │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
Export (Parquet/CSV/JSON)
```

### C.4 LLM Integration

```
┌─────────────────────────────────────────────────────────────┐
│                    LlamaServerManager                        │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ spawn_server() → health_check_loop() → graceful_stop()  ││
│  └─────────────────────────────────────────────────────────┘│
│                          │                                   │
│                          ▼ HTTP :8080                        │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ llama-server (subprocess)                               ││
│  │   Model: sentiment-llama-3b.gguf                        ││
│  │   Endpoint: /v1/chat/completions (OpenAI-compatible)    ││
│  │   Health: /health                                        ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

**LLM Routing Strategy:**
1. **Local-first**: llama-server (subprocess) → vLLM → Ollama
2. **Cloud fallback**: OpenAI → Anthropic → Google
3. **Cost-aware**: Free local providers before paid cloud

---

## Appendix D: Vendor-Agnostic Abstractions

### D.1 Core Traits

All external dependencies are behind Rust traits for zero lock-in:

```rust
// LLM Provider (3 methods)
#[async_trait]
pub trait LLMProvider: Send + Sync {
    fn capabilities(&self) -> &ProviderCapabilities;
    async fn analyze_batch(&self, request: AnalysisRequest) -> Result<Vec<AnalysisResult>, LLMError>;
    async fn health_check(&self) -> bool;
}

// Compute Node (8 methods)
#[async_trait]
pub trait ComputeNode: Send + Sync {
    fn node_id(&self) -> &str;
    fn node_type(&self) -> &str;
    fn input_schema(&self) -> Option<Arc<Schema>>;
    fn output_schema(&self) -> Arc<Schema>;
    fn dependencies(&self) -> &[String];
    async fn transform(&self, data: Option<RecordBatch>, ctx: &ExecutionContext) -> Result<NodeResult>;
    fn resource_requirements(&self) -> ResourceSpec;
    fn validate_input(&self, data: &RecordBatch) -> Vec<String>;
}

// State Store (12 methods)
#[async_trait]
pub trait StateStore: Send + Sync {
    async fn get(&self, key: &str) -> Option<Vec<u8>>;
    async fn set(&self, key: &str, value: Vec<u8>, ttl: Option<Duration>) -> Result<()>;
    async fn delete(&self, key: &str) -> bool;
    async fn increment(&self, key: &str, delta: i64, ttl: Option<Duration>) -> i64;
    // ... additional methods for sets, batch operations
}

// Secret Store (6 methods)
#[async_trait]
pub trait SecretStore: Send + Sync {
    async fn get_secret(&self, name: &str) -> Result<String>;
    async fn set_secret(&self, name: &str, value: &str, secret_type: SecretType) -> Result<()>;
    async fn rotate_secret(&self, name: &str, new_value: &str, grace_period: Duration) -> Result<()>;
    // ... additional methods
}
```

### D.2 Swappable Implementations

| Trait | Default | Alternatives | Swap Method |
|-------|---------|--------------|-------------|
| `LLMProvider` | LlamaServerAdapter | OpenAIAdapter, AnthropicAdapter, OllamaAdapter | TOML config |
| `StateStore` | MemoryStateStore | RedisStateStore, DragonflyAdapter | TOML config |
| `Persistence` | DuckDBPersistence | PostgresPersistence | TOML config |
| `Cache` | MemoryCache | RedisCache, ValkeyCache | TOML config |
| `Exporter` | ParquetExporter | CSVExporter, JSONExporter | TOML config |
| `SecretStore` | EnvSecretStore | VaultAdapter, AWSSecretsAdapter | TOML config |

### D.3 Configuration-Driven Swapping

```toml
# config.toml - Change implementations without code changes

[llm]
mode = "subprocess"  # "subprocess" | "external"
provider = "llama-server"  # "llama-server" | "ollama" | "openai" | "anthropic"

[llm.subprocess]
binary_path = "llama-server"
model_path = "./models/sentiment-llama-3b.gguf"
port = 8080

[llm.fallback]
providers = ["openai", "anthropic"]  # Cloud fallback chain

[cache]
backend = "memory"  # "memory" | "redis" | "dragonfly"
redis_url = "${REDIS_URL}"  # Environment variable interpolation

[persistence]
backend = "duckdb"  # "duckdb" | "postgres"
duckdb_path = "./data/feedback_arrow.duckdb"

[secrets]
backend = "env"  # "env" | "vault" | "aws"
```

---

## Appendix E: Deployment

### E.1 Single Binary Deployment

```bash
# Build release binary (~20-30MB static binary)
cargo build --release

# Binary location
./target/release/feedback-arrow

# Required files alongside binary:
# - config.toml (configuration)
# - models/sentiment-llama-3b.gguf (LLM model)
# - language_packs/ (JSON resources)
```

### E.2 Cloudflare Tunnel Deployment

```bash
# 1. Install cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared

# 2. Authenticate with Cloudflare
./cloudflared tunnel login

# 3. Create tunnel
./cloudflared tunnel create feedback-arrow

# 4. Configure tunnel (config.yml)
cat > ~/.cloudflared/config.yml << EOF
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: feedback.yourdomain.com
    service: http://localhost:8000
  - service: http_status:404
EOF

# 5. Add DNS record
./cloudflared tunnel route dns feedback-arrow feedback.yourdomain.com

# 6. Run tunnel (background)
./cloudflared tunnel run feedback-arrow &

# 7. Run application
./feedback-arrow serve --config config.toml
```

### E.3 Docker Deployment

```dockerfile
FROM rust:1.75-slim AS builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/feedback-arrow /usr/local/bin/
COPY config.toml /etc/feedback-arrow/
COPY language_packs /usr/share/feedback-arrow/language_packs
COPY models /usr/share/feedback-arrow/models
EXPOSE 8000
CMD ["feedback-arrow", "serve", "--config", "/etc/feedback-arrow/config.toml"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  feedback-arrow:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./config.toml:/etc/feedback-arrow/config.toml
      - ./models:/usr/share/feedback-arrow/models
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    restart: unless-stopped

  cloudflared:
    image: cloudflare/cloudflared:latest
    command: tunnel run
    volumes:
      - ./cloudflared:/etc/cloudflared
    restart: unless-stopped
```

### E.4 Multi-Tenant Configuration

```toml
[tenancy]
enabled = true
id_format = "ulid"  # org_01hqx..., ws_01hqx..., proj_01hqx...

[tenancy.tiers]
[tenancy.tiers.free]
rate_limit_per_minute = 10
daily_rows = 1000
storage_mb = 100
concurrent_jobs = 1

[tenancy.tiers.pro]
rate_limit_per_minute = 100
daily_rows = 100000
storage_mb = 10240
concurrent_jobs = 5

[tenancy.tiers.enterprise]
rate_limit_per_minute = 1000
daily_rows = 0  # Unlimited
storage_mb = 1048576  # 1TB
concurrent_jobs = 50
```

### E.5 API Key Format

```
fa_{environment}_{32_char_secret}

Examples:
fa_live_aBcDeFgHiJkLmNoPqRsTuVwXyZ012345  # Production
fa_test_aBcDeFgHiJkLmNoPqRsTuVwXyZ012345  # Testing
```

### E.6 Health & Monitoring

```bash
# Health check endpoint
curl http://localhost:8000/api/v1/health

# Response
{
  "status": "healthy",
  "version": "1.0.0",
  "llm": { "status": "connected", "provider": "llama-server" },
  "cache": { "status": "connected", "backend": "memory" },
  "persistence": { "status": "connected", "backend": "duckdb" }
}

# Metrics endpoint (Prometheus format)
curl http://localhost:8000/metrics
```

---

## Document Information

**Version:** 2.0.0
**Updated:** December 2025
**Type:** Business Requirements + Technical Implementation Specification

---

*This document describes business logic and domain rules with Rust + Arrow implementation details. Appendices C-E provide technical specifications for the core stack, vendor-agnostic abstractions, and deployment methodology.*
