# Language Pack Specification

**Status:** Defined
**Date:** 2025-12-15
**Covers Gap:** #3 - Language Pack Structure

---

## Overview

Language packs provide locale-specific lexicons, patterns, and thresholds for domain analysis. Each language is a self-contained directory with JSON files.

---

## Directory Structure

```
language_packs/
├── _schema/
│   └── pack_schema.json       # JSON Schema for validation
├── es/
│   ├── manifest.json          # Pack metadata
│   ├── sentiment.json         # Sentiment lexicon
│   ├── keywords.json          # Domain keywords
│   ├── patterns.json          # Regex patterns
│   ├── negations.json         # Negation words
│   └── thresholds.json        # Scoring thresholds
├── en/
│   ├── manifest.json
│   ├── sentiment.json
│   ├── keywords.json
│   ├── patterns.json
│   ├── negations.json
│   └── thresholds.json
└── index.json                 # Available packs registry
```

---

## File Specifications

### `manifest.json`
```json
{
  "language_code": "es",
  "language_name": "Spanish",
  "version": "1.0.0",
  "last_updated": "2025-12-15",
  "coverage": {
    "sentiment": true,
    "churn": true,
    "nps": true,
    "pain_points": true
  }
}
```

### `sentiment.json`
```json
{
  "positive": {
    "excelente": 0.9,
    "bueno": 0.6,
    "satisfecho": 0.7,
    "recomiendo": 0.8,
    "fantástico": 0.95
  },
  "negative": {
    "terrible": -0.9,
    "malo": -0.6,
    "frustrado": -0.7,
    "decepcionado": -0.8,
    "pésimo": -0.95
  },
  "intensifiers": {
    "muy": 1.3,
    "bastante": 1.2,
    "poco": 0.7,
    "nada": 0.0
  }
}
```

### `keywords.json`
```json
{
  "churn_signals": [
    "cancelar",
    "baja",
    "terminar",
    "devolver",
    "reembolso",
    "cambiar de proveedor"
  ],
  "loyalty_signals": [
    "años usando",
    "siempre compro",
    "cliente fiel",
    "recomiendo a todos"
  ],
  "urgency_markers": [
    "urgente",
    "inmediato",
    "ahora mismo",
    "cuanto antes"
  ],
  "pain_categories": {
    "price": ["caro", "precio", "costoso", "económico"],
    "quality": ["calidad", "defecto", "roto", "funciona mal"],
    "service": ["atención", "espera", "respuesta", "soporte"],
    "delivery": ["envío", "llegó tarde", "no llegó", "demora"]
  }
}
```

### `patterns.json`
```json
{
  "nps_score_extract": "(?:puntuación|nota|calificación)[:\\s]*(\\d{1,2})",
  "time_reference": "(\\d+)\\s*(días?|semanas?|meses?|años?)",
  "product_code": "[A-Z]{2,4}-\\d{4,8}",
  "currency_amount": "(\\d+[.,]?\\d*)\\s*(€|EUR|euros?)",
  "email_pattern": "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
}
```

### `negations.json`
```json
{
  "words": ["no", "nunca", "jamás", "tampoco", "ni", "sin"],
  "scope": 3,
  "flip_sentiment": true
}
```
- `scope`: Number of words affected after negation
- `flip_sentiment`: Whether negation inverts sentiment polarity

### `thresholds.json`
```json
{
  "sentiment": {
    "positive_min": 0.2,
    "negative_max": -0.2,
    "strong_positive": 0.6,
    "strong_negative": -0.6
  },
  "churn": {
    "high_risk": 0.7,
    "medium_risk": 0.4,
    "low_risk": 0.2
  },
  "nps": {
    "promoter_min": 9,
    "passive_min": 7,
    "detractor_max": 6
  },
  "confidence": {
    "minimum_acceptable": 0.6,
    "high_confidence": 0.85
  }
}
```

### `index.json` (root level)
```json
{
  "available": ["es", "en"],
  "default": "es",
  "fallback_chain": {
    "es-MX": "es",
    "es-AR": "es",
    "en-GB": "en",
    "en-AU": "en"
  }
}
```

---

## Loading Strategy

```
1. Check index.json for available packs
2. Load requested language (e.g., "es")
3. If regional variant requested (e.g., "es-MX"), use fallback_chain
4. Cache loaded pack in memory (hot) or R2/disk (cold)
5. Validate against _schema/pack_schema.json on load
```

---

## Cold Storage

Language packs are ideal for cold storage:
- **Cloudflare R2:** Store as `language_packs/{lang}.tar.gz` or individual JSON files
- **Local cache:** `~/.feedback-arrow/language_packs/`
- **Bundle with app:** Include in Docker image for offline operation

---

## Extensibility

To add a new language:
1. Create `language_packs/{code}/` directory
2. Copy structure from existing pack
3. Translate/adapt all JSON files
4. Add to `index.json` available list
5. Validate with schema

---

## Validation

All packs must pass JSON Schema validation before use. Schema enforces:
- Required files present
- Correct key structure
- Score values in valid ranges (-1.0 to 1.0 for sentiment)
- Valid regex patterns (tested at load time)

---

**Next:** Gap 4 - Export Interface Detail
