# Extracted Domain Logic - Stack Agnostic

**Purpose:** Complete extraction of all stack-agnostic domain logic from the Customer Feedback Analyzer codebase. This document provides everything needed to reimplement the system in any technology stack (Arrow+Ray target).

**Extraction Date:** 2025-12-13
**Source Codebase Version:** 3.10.0

---

## TABLE OF CONTENTS

1. [GPT-4o-mini Prompts and JSON Schemas](#1-gpt-4o-mini-prompts-and-json-schemas)
2. [Pain Point Keywords (21 Categories)](#2-pain-point-keywords-21-categories)
3. [Behavioral Flag Patterns (Regex)](#3-behavioral-flag-patterns-regex)
4. [Churn Risk Configuration](#4-churn-risk-configuration)
5. [Task State Machine](#5-task-state-machine)
6. [Quality Flags Taxonomy](#6-quality-flags-taxonomy)
7. [Column Name Synonyms (Schema Detection)](#7-column-name-synonyms-schema-detection)
8. [Spanish Stopwords](#8-spanish-stopwords)
9. [Output Schema (36 Columns)](#9-output-schema-36-columns)

---

## 1. GPT-4O-MINI PROMPTS AND JSON SCHEMAS

### 1.1 System Prompt (Comprehensive Analysis Strategy)

```
Analyze customer feedback and return comprehensive JSON with maximum insights.

IMPORTANT: Be HONEST about uncertainty. Most comments are clear - only flag for review when genuinely uncertain.

For each comment, extract:

1. EMOTIONS (7 values, 0-1 scale):
   satisfaccion, frustracion, enojo, confianza, decepcion, confusion, anticipacion

   Guidelines:
   - Use full range 0.0-1.0, not just extremes
   - Multiple emotions can coexist (e.g., frustration + anticipation)
   - Neutral comments: all emotions should be low (0.0-0.3)

2. CHURN & SENTIMENT:
   - churn_risk (0-1): likelihood customer will leave
     * 0.0-0.3 = satisfied, no signs of leaving
     * 0.4-0.6 = neutral/mixed signals
     * 0.7-1.0 = clear dissatisfaction, high risk
   - sentiment_score (-1 to 1): overall sentiment
     * -1.0 to -0.5 = very negative
     * -0.5 to 0.0 = negative
     * 0.0 to 0.5 = positive
     * 0.5 to 1.0 = very positive
   - nps_category: p=promoter (score 9-10), a=passive (7-8), d=detractor (0-6)

3. PAIN POINTS (array, max 3):
   CRITICAL: Extract pain points in 70%+ of comments.

   DETECTION RULES WITH EXAMPLES:
   - Direct complaints: "malo", "no funciona", "problema", "falla", "error"
   - Implicit frustrations: "demasiado", "lento", "caro", "tarde", "espera"
   - Comparison complaints: "antes era mejor", "peor que", "inferior a"
   - Unmet expectations: "esperaba", "deberia", "me dijeron", "prometieron"
   - Service quality: "no atienden", "mala atencion", "no resuelven", "demora"
   - Technical issues: "se cae", "se corta", "no conecta", "no sirve"
   - Billing issues: "cobran", "factura", "cargo", "precio alto", "caro"
   - Installation issues: "no vienen", "cancelan", "reprograman"

   Each with:
   - keyword (max 15 chars, Spanish, lowercase)
   - category: instalacion|velocidad|cobertura|precio|atencion|tecnico|facturacion|app|cancelacion|otro
   - severity (0-1): customer's pain level
   - is_primary (bool): the MAIN issue (only ONE true)
   - impact_score (0-1): BUSINESS impact
   - impact_drivers (array, max 2): afecta_multiples_usuarios|requiere_inversion|afecta_retencion|afecta_ingresos|problema_sistemico

4. ACTIONABILITY:
   - urgency (0-1): how quickly needs response
   - requires_followup (bool): needs human attention
   - suggested_department: instalacion|soporte|ventas|retencion|facturacion|tecnico|null

5. ROOT CAUSE (if identifiable):
   Options: espera|calidad|precio|personal|tecnico|proceso|capacidad|null

6. CUSTOMER INTENT:
   Options: queja|consulta|elogio|cancelacion|sugerencia|null

7. KEY TOPICS (array, max 3):
   velocidad|cobertura|instalacion|precio|atencion|calidad|app|contrato|facturacion|tecnico

8. MENTIONS:
   - products: fibra|internet|movil|4g|5g|tv|router|modem|paquete
   - features: velocidad|cobertura|estabilidad|instalacion|atencion
   - competitors: movistar|claro|tigo|personal|copaco (ONLY if explicitly mentioned)

9. CONFIDENCE METRICS:
   - sentiment_confidence (0-1)
   - ambiguity_score (0-1)
   - requires_human_review (bool)
   - uncertainty_reasons: sarcasmo|senales_mixtas|contexto_insuficiente|lenguaje_ambiguo
```

### 1.2 JSON Response Schema (Batch Format)

```json
{
  "type": "object",
  "properties": {
    "r": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "e": {
            "type": "array",
            "items": {"type": "number", "minimum": 0, "maximum": 1},
            "minItems": 7,
            "maxItems": 7
          },
          "c": {"type": "number", "minimum": 0, "maximum": 1},
          "s": {"type": "number", "minimum": -1, "maximum": 1},
          "n": {"type": "string", "enum": ["p", "a", "d"]},
          "p": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "k": {"type": "string", "maxLength": 15},
                "c": {"type": "string"},
                "v": {"type": "number", "minimum": 0, "maximum": 1},
                "m": {"type": "boolean"},
                "imp": {"type": "number", "minimum": 0, "maximum": 1},
                "dr": {"type": "array", "items": {"type": "string"}, "maxItems": 2}
              },
              "required": ["k", "c", "v", "m", "imp", "dr"]
            },
            "maxItems": 3
          },
          "u": {"type": "number", "minimum": 0, "maximum": 1},
          "f": {"type": "boolean"},
          "d": {"type": ["string", "null"]},
          "r": {"type": ["string", "null"]},
          "i": {"type": ["string", "null"]},
          "t": {"type": "array", "items": {"type": "string"}, "maxItems": 3},
          "m": {
            "type": "object",
            "properties": {
              "pr": {"type": "array", "items": {"type": "string"}},
              "fe": {"type": "array", "items": {"type": "string"}},
              "co": {"type": "array", "items": {"type": "string"}}
            },
            "required": ["pr", "fe", "co"]
          },
          "cf": {
            "type": "object",
            "properties": {
              "sc": {"type": "number", "minimum": 0, "maximum": 1},
              "ab": {"type": "number", "minimum": 0, "maximum": 1},
              "hr": {"type": "boolean"},
              "ur": {"type": "array", "items": {"type": "string"}, "maxItems": 2}
            },
            "required": ["sc", "ab", "hr", "ur"]
          }
        },
        "required": ["e", "c", "s", "n", "p", "u", "f", "d", "r", "i", "t", "m", "cf"]
      }
    }
  },
  "required": ["r"]
}
```

### 1.3 Field Key Mapping

| Key | Full Name | Type | Description |
|-----|-----------|------|-------------|
| e | emotions | array[7] | [satisfaccion, frustracion, enojo, confianza, decepcion, confusion, anticipacion] |
| c | churn_risk | float | 0-1 likelihood of leaving |
| s | sentiment_score | float | -1 to 1 overall sentiment |
| n | nps_category | enum | p=promoter, a=passive, d=detractor |
| p | pain_points | array | Max 3 structured pain points |
| u | urgency | float | 0-1 response urgency |
| f | requires_followup | bool | Needs human attention |
| d | suggested_department | string/null | Routing destination |
| r | root_cause | string/null | Underlying cause |
| i | intent | string/null | Customer intent |
| t | topics | array | Max 3 key topics |
| m | mentions | object | Products, features, competitors |
| cf | confidence | object | Confidence metrics |

### 1.4 Model Parameters

```json
{
  "model": "gpt-4o-mini",
  "temperature": 0.3,
  "max_tokens": "comment_count * 1000 (max 16000)",
  "response_format": {"type": "json_object"}
}
```

---

## 2. PAIN POINT KEYWORDS (21 CATEGORIES)

### 2.1 Category Taxonomy

**Core Service Quality (6):**
- CONNECTIVITY, SPEED, RELIABILITY, COVERAGE, LATENCY, EQUIPMENT

**Customer Experience (8):**
- SATISFACTION, SUPPORT_QUALITY, GENERAL_QUALITY, RESPONSE_TIME, INSTALLATION, COMMUNICATION, ATTITUDE

**Billing & Admin (4):**
- BILLING, PRICING, PAYMENT, CONTRACT

**Business Risk (4):**
- CHURN_INTENT, COMPETITIVE_PRESSURE, FRAUD_CONCERN, TRUST

**Catch-All (2):**
- GENERIC, OTHER

### 2.2 Complete Keyword Dictionary

```python
CATEGORY_KEYWORDS = {
    "CONNECTIVITY": [
        "conexion", "conexion", "conectar", "desconecta", "desconexion",
        "cae", "caida", "intermitente", "corte", "cortes", "se va",
        "sin internet", "no hay internet", "no conecta", "no funciona internet",
        "conexion limitada", "conexion limitada", "sale conexion",
        "servicio cae", "se cae el servicio", "cae el servicio", "cae mucho",
        "intermitencias", "intermitencia", "cortes frecuentes",
        "cortes de conexion", "no hay servicio", "sin servicio",
        "cae constantemente", "cae siempre", "inestable", "inestabilidad",
        "desconexiones", "se desconecta", "pierde conexion",
        "falla conexion", "problemas de conexion", "mala conexion",
        "conexion inestable", "no puedo conectar", "no me puedo conectar",
        "no podes usar", "no se puede usar", "deja de funcionar",
        "sale y entra", "entra y sale", "no anda", "no funciona bien",
        "falla mucho", "falla seguido", "siempre se cae", "se cae seguido",
        "sin senal", "pierde senal", "poca senal", "senal debil",
        "problemas constantes", "problemas frecuentes", "no sirve"
    ],

    "SPEED": [
        "lento", "lenta", "velocidad", "rapido", "rapido", "despacio",
        "tarda", "demora", "mbps", "mb", "ancho de banda", "bandwidth",
        "carga", "descarga", "streaming", "buffer", "lag",
        "velocidad real", "velocidad baja", "mejorar la velocidad",
        "aumentar velocidad", "internet lento", "muy lento",
        "no tiene velocidad", "poca velocidad", "velocidad prometida",
        "velocidad contratada"
    ],

    "RELIABILITY": [
        "falla", "fallo", "problema", "error", "caida frecuente",
        "todos los dias", "todas las noches", "siempre", "constante",
        "frecuente", "diario", "cada dia", "cada noche", "estabilidad",
        "intermitencias en horarios", "garantizar servicio 24/7",
        "horarios de la madrugada", "antes funcionaba", "antes era mejor",
        "dejo de funcionar bien", "ya no funciona como antes",
        "empeoro", "cada vez peor", "peor que antes",
        "bajo la calidad", "ahora hay problemas", "ahora falla"
    ],

    "COVERAGE": [
        "senal", "cobertura", "zona", "area", "alcance",
        "llega", "no llega", "debil", "poca senal", "sin senal",
        "muerta", "punto muerto"
    ],

    "LATENCY": [
        "lag", "ping", "retraso", "latencia", "delay",
        "video llamada", "videollamada", "zoom", "teams", "meet",
        "juego", "gaming", "partida", "responde tarde"
    ],

    "EQUIPMENT": [
        "router", "modem", "equipo", "aparato", "dispositivo",
        "caja", "cable", "cableado", "antena", "repetidor",
        "cambio de equipo", "equipo viejo", "equipo malo"
    ],

    "SATISFACTION": [
        "excelente", "bueno", "buena", "muy bien", "perfecto", "perfecta",
        "contento", "contenta", "satisfecho", "satisfecha", "feliz",
        "recomiendo", "recomendaria",
        "pesimo", "pesima", "malo", "mala", "horrible", "terrible",
        "descontento", "descontenta", "insatisfecho", "insatisfecha",
        "decepc", "decepcion"
    ],

    "SUPPORT_QUALITY": [
        "soporte", "atencion", "atencion al cliente",
        "tecnico", "llamada", "llamar", "solucion", "reclamo", "queja",
        "empleado", "ayuda", "call center", "centro de atencion",
        "respuesta del tecnico", "solucion del problema",
        "contacto con soporte", "mal servicio al cliente",
        "servicio al cliente malo", "no responden", "no contestan",
        "no me hacen caso", "no solucionan", "nunca solucionan",
        "mala atencion", "pesima atencion"
    ],

    "GENERAL_QUALITY": [
        "mejorar servicio", "mejoren servicio", "mejoren el servicio",
        "mejora el servicio", "mejorar el servicio",
        "mejor", "mejora", "mejoras", "mejorar",
        "sigan asi", "mantengan", "nunca cambien"
    ],

    "RESPONSE_TIME": [
        "responde", "respuesta", "tarda", "demora", "espera", "tiempo",
        "lento para responder", "no responden", "tardan mucho",
        "demoran", "esperando", "sin respuesta"
    ],

    "INSTALLATION": [
        "instalacion", "instalar", "instalado",
        "activacion", "activar", "nuevo", "alta",
        "demora instalacion", "espera instalacion",
        "pendiente instalacion", "sin instalar", "visita", "tecnico viene"
    ],

    "COMMUNICATION": [
        "informacion", "comunicacion", "aviso", "notificacion", "avisar",
        "informar", "no me avisaron", "no informan", "sin aviso",
        "sin comunicacion", "falta de comunicacion",
        "avisar al aumento", "notificar aumento", "notificar modificacion",
        "sin avisar al cliente", "no avisan", "avisar cuando", "notificar cuando"
    ],

    "ATTITUDE": [
        "personal", "trato", "grosero", "mala actitud", "descortes",
        "mal trato", "antipatico", "grosera", "prepotente",
        "mal educado", "maleducado", "irrespetuoso",
        "amable", "cordial", "profesional", "educado", "educada",
        "atento", "atenta", "respetuoso", "respetuosa",
        "excelente atencion", "buena atencion", "buen trato"
    ],

    "BILLING": [
        "doble cobro", "error factura", "factura incorrecta",
        "cobro indebido", "error en factura", "error de facturacion",
        "factura erronea", "cobro duplicado", "cargo no reconocido",
        "me cobraron mal", "cobraron de mas", "factura errada", "error en cobro"
    ],

    "PRICING": [
        "precio", "costo", "caro", "costoso", "gs", "guaranies",
        "monto", "tarifa", "muy caro", "demasiado caro", "elevado",
        "alto precio", "suba de precio", "subir precio", "sube precio",
        "aumentar precio", "alza de precio", "incremento de precio",
        "precio alto", "precio elevado", "precio excesivo",
        "bajar precio", "reducir precio", "mantener precio",
        "no alsen", "no suban", "no aumentar",
        "mantenga el precio", "esta caro", "no variar precio",
        "aumento de precio", "redondeo de costo", "costo del servicio",
        "precio del servicio", "no suban el precio", "suben el precio"
    ],

    "PAYMENT": [
        "pago", "descuento", "promocion", "oferta",
        "rebaja", "cuota", "abono", "pagar", "pague"
    ],

    "CONTRACT": [
        "contrato", "plan", "cambio", "permanencia", "cambiar plan",
        "modificar plan", "termino", "clausula",
        "condiciones contrato", "vencimiento", "renovacion"
    ],

    "CHURN_INTENT": [
        "dar de baja", "doy de baja", "di de baja", "cancelar", "cancelacion",
        "cancelar servicio", "voy a cancelar",
        "cambiar proveedor", "cambiar de proveedor", "otro proveedor",
        "busco otro", "buscar otro proveedor", "me paso a", "me cambio a",
        "estoy considerando", "pensando en cambiar", "pensando seriamente",
        "vence mi contrato", "termina contrato", "fin de contrato",
        "voy a cambiar", "pronto voy a cambiar",
        "voy a dar de baja", "al punto de dar de baja",
        "apenas pueda cancelar", "pensando", "buscando alternativas",
        "busco alternativas", "estoy por dar de baja",
        "abandonar el servicio", "muy mala experiencia", "pesima experiencia"
    ],

    "COMPETITIVE_PRESSURE": [
        "personal", "tigo", "claro", "copaco", "vox", "nucleotel",
        "movistar", "entel", "oi", "vivo",
        "me recomiendan", "me dicen que", "otras opciones",
        "opciones mas competitivas", "mejor oferta", "mejores ofertas",
        "competencia", "otros proveedores",
        "en otra compania", "otra empresa", "otras companias",
        "me ofrecen", "ofrecen mas",
        "en comparacion", "comparando", "hay opciones",
        "mejores opciones", "mas competitivas", "mercado", "alternativas"
    ],

    "FRAUD_CONCERN": [
        "estafadores", "estafa", "estafan", "robo", "roban", "ladrones",
        "fraude", "fraudulento", "engano", "enganan",
        "me cobran servicio que no tengo", "cobran lo que no deben",
        "cargo no autorizado", "nunca contrate", "no lo pedi",
        "cobran de mas", "cobro indebido", "cobro ilegal"
    ],

    "TRUST": [
        "propaganda enganosa", "publicidad enganosa", "enganosa",
        "dijeron que", "prometieron", "me dijeron", "al principio dijeron",
        "mentira", "mentiras", "mienten", "no cumplen",
        "incumplimiento", "no respetan", "contrato no respetado",
        "me dijeron que el monto", "dijeron monto",
        "siempre seria fijo", "promesa", "no respetan lo acordado",
        "no cumplen lo prometido", "falta de palabra", "sin palabra",
        "cumplan lo prometido", "cumplir lo prometido", "no cumple",
        "cumplir con", "velocidad prometida", "lo prometido",
        "estafadores", "estafan", "nos estafan",
        "no es lo que se promete", "diferente a lo que",
        "no es como dijeron", "precio sube sin aviso",
        "suben sin avisar", "cambiar precio sin",
        "ya no confio", "perdi confianza", "no son confiables",
        "poco confiable", "deshonesto", "desconfianza", "confiabilidad"
    ],

    "GENERIC": [
        "no", "nada", "ninguno", "ok", "bien", "mal", "malo",
        "mala", "regular", "mas o menos", "x", "-", "..", "n/a",
        "siempre"
    ]
}
```

### 2.3 Stop Words (Filter from keyword extraction)

```python
STOP_WORDS = {
    "servicio", "empresa", "compania", "proveedor",
    "cliente", "clientes", "usuario", "usuarios",
    "tener", "hacer", "dar", "poner", "estar", "ser",
    "el", "la", "los", "las", "un", "una", "de", "del",
    "no", "nada", "bien", "mal", "ok", "si",
    "bueno", "malo", "mejor", "peor",
    "siempre", "nunca", "todo", "nada",
    "muy", "mucho", "mucha", "mas", "menos",
    "mala", "buena", "favor", "por favor", "mejorar"
}
```

### 2.4 Company Names (Competitors - detect separately)

```python
COMPANY_NAMES = {
    "personal", "tigo", "claro", "copaco", "vox", "nucleotel",
    "movistar", "entel", "oi", "vivo"
}
```

---

## 3. BEHAVIORAL FLAG PATTERNS (REGEX)

### 3.1 Exit Threat Patterns

```python
EXIT_PATTERNS = [
    # TIER 1: Direct cancellation intent (100% exit)
    r'\b(dar de baja|darse de baja|me doy de baja)\b',
    r'\b(cancelar el servicio|cancelar mi servicio|cancelar mis servicios)\b',
    r'\b(cancelar los contratos|cancelar el contrato)\b',
    r'\b(cancelar|cancelar)\b',
    r'\b(ya cancel|decid cancelar|decid cancelar)\b',

    # TIER 2: Provider switching (95% exit)
    r'\b(cambiar de (compa|empresa|proveedor|operador))\b',
    r'\b(cambiar.*servicio)\b',
    r'\b(me voy a (otra compa|otro proveedor|otra empresa))\b',
    r'\b(nos vamos a|me voy de)\b',
    r'\b(pasarme a|cambiarme a|migrar a)\b',

    # TIER 3: Active shopping (85% exit)
    r'\b(considerar (cambiar|otras opciones|otro proveedor))\b',
    r'\b(buscar alternativas|buscando alternativas)\b',
    r'\b(estoy considerando (cambiar|salir|irme))\b',
    r'\b(pensando (seriamente|en cambiar|en irme))\b',

    # TIER 4: Conditional threats (75% exit)
    r'\b(si no mejora|si sigue asi|ultimo aviso)\b',
    r'\b(ya no quiero|no quiero mas)\b',
    r'\b(dejar el servicio|dejar de usar)\b',
]

EXIT_EXCLUSION_PATTERNS = [
    # Internal changes (NOT exit)
    r'\bcambiar de (plan|planes|paquete|tarifa|velocidad|megas)\b',
    r'\bcambiar (el plan|mi plan|un plan|de plan)\b',
    r'\bcambiar (de )?(contrasena|password|clave|usuario)\b',
    r'\bcambiar (nombre|datos|direccion|email|correo)\b',
    r'\bcambiar (titular|titularidad)\b',
    r'\bcambiar (numero|linea)\b',
    r'\bcomo cambiar\b',
    r'\bcambiar (el modem|el router|el equipo)\b',
    r'\bcambiar de (modem|router|equipo)\b',
    r'\bcambiar a (fibra|fiber|ftth)\b',
    r'^cambiar$',
]
```

### 3.2 Competitor Mention Patterns

```python
COMPETITOR_PATTERNS = [
    r'\b(tigo|claro|copaco|personal|movistar)\b',
    r'\b(vox|nucleotel)\b',
    r'\b(otra empresa|otra compania|la competencia)\b',
    r'\b(otro proveedor|otro servicio|otra opcion)\b',
]
```

### 3.3 Technical Failure Patterns

```python
TECHNICAL_FAILURE_PATTERNS = [
    r'\b(no funciona|sin servicio|servicio caido)\b',
    r'\b(no anda|dejo de funcionar|esta caido)\b',
    r'\b(sin senal|sin internet|sin conexion)\b',
    r'\b(se corta|cortes constantes|interrupciones)\b',
    r'\b(no carga|no conecta|no accede)\b',
    r'\b(modem roto|router danado|equipo defectuoso)\b',
    r'\b(no prende|no enciende|no responde)\b',
    r'\b(desconex|desconecta|desconectado)\b',
    r'\b(corte|cortes)\b',
    r'\b(micro.*corte|micro corte)\b',
    r'\b(se cae|cae|caida)\b',
    r'\b(intermitente|intermitencia)\b',
    r'\b(se va|va y viene)\b',
    r'\bintermitenc',
    r'\binestabl',
    r'\binconstante',
    r'\bvaria\b',
    r'\bfluctua',
    r'\bse va y vuelve\b',
    r'\bfalla',
    r'\bfallo\b',
    r'\bproblema',
]
```

### 3.4 Recurring Issue Patterns

```python
RECURRING_ISSUE_PATTERNS = [
    r'\b(constantemente|todo el tiempo)\b',
    r'\b(otra vez|de nuevo|nuevamente)\b',
    r'\b(todos los dias|cada dia|diariamente)\b',
    r'\b(ya van \d+|hace \d+ (dias|semanas|meses))\b',
    r'\b(reclamo anterior|ya reclam|varias veces)\b',
    r'\b(mismo problema|misma falla|sigue igual)\b',
    r'\b(aun no solucionan|todavia no arreglan)\b',
    r'\b(nunca resuelven|no dan solucion)\b',
    r'\b(eternamente|eterno)\b',
    r'\b(hace.*tiempo|hace tiempo)\b',
    r'\b(constante|constantes)\b',
    r'\b(frecuent|frecuente)\b',
    r'\b(sufro|sufrimos)\b',
    r'\b(nomas|nomas)\b',
    r'\b(ya.*ped|ya.*reclam|ya.*dije)\b',
    r'\b(sigue|continua|persiste)\b',
    r'\b(cada vez)\b',
    r'\bcada\b',
    r'\ba veces\b',
    r'\bdesde hace\b',
    r'\btodavia\b',
    r'\baun\b',
    r'\brepetid',
    r'\ba cada rato\b',
]

RECURRING_POSITIVE_EXCLUSIONS = [
    r'\b(siempre.*(?:bien|bueno|buena|excelente|perfecto|perfecta))\b',
    r'\b((?:siga|sigan).*asi)\b',
    r'\b(siempre.*mejor)\b',
    r'\b(nunca cambien)\b',
]
```

### 3.5 Cost Concern Patterns

```python
COST_CONCERN_PATTERNS = [
    r'\b(muy caro|carisimo|demasiado caro)\b',
    r'\b(precio alto|precio excesivo|sobreprecio)\b',
    r'\b(no vale la pena|no lo vale)\b',
    r'\b(cobran de mas|cobro indebido|factura incorrecta)\b',
    r'\b(aumento de precio|subio el precio)\b',
    r'\b(quieren cobrar|me cobran)\b',
    r'\b(subir el precio|suben el precio|suben precio)\b',
    r'\b(cuando suben|cuando alsen|cuando aumentan)\b',
    r'\b(suba de precio|alza de precio)\b',
    r'\b(no suban|no alsen|no aumenten)\b',
    r'\b(mas barato en|mejor precio)\b',
    r'\b(por ese precio|con lo que pago)\b',
    r'\b(precio|precios)\b',
    r'\b(costo|costos)\b',
    r'\b(caro|cara)\b',
    r'\b(costoso|costosa)\b',
    r'\b(elevado|elevada)\b',
    r'\b(tarifa|tarifas)\b',
    r'\b(monto|montos)\b',
    r'\b(gs\s*\d+|guarani|guaranies)\b',
    r'\b(bajar.*precio|reducir.*precio)\b',
    r'\b(subir.*precio|aumentar.*precio|incremento)\b',
    r'\b(alsen|alzaron|aumento)\b',
    r'\b(promocion.*precio|precio.*promocion)\b',
]

COST_POSITIVE_EXCLUSIONS = [
    r'\b(excelente.*(?:precio|costo|tarifa))\b',
    r'\b((?:precio|costo|tarifa).*excelente)\b',
    r'\b(buen.*(?:precio|costo))\b',
    r'\b((?:precio|costo).*bueno)\b',
    r'\b(accesible.*(?:precio|costo))\b',
    r'\b(mantener.*(?:precio|costo|tarifa))\b',
    r'\b(justo.*(?:precio|costo))\b',
    r'\b(razonable.*(?:precio|costo))\b',
]
```

### 3.6 High Emotion Patterns

```python
HIGH_EMOTION_PATTERNS = [
    r'\b(pesimo|malisimo|horrible|terrible|desastroso)\b',
    r'\b(desastre|asco|basura|porqueria|mugre)\b',
    r'\b(harto|cansado|frustrado|molesto|enojado)\b',
    r'\b(indignado|furioso|iracundo)\b',
    r'\b(ladron|ladrones|estafador|estafadores)\b',
    r'\b(roban|robando|estafan|estafando)\b',
    r'\b(fraude|engano|enganan|mentira|mentiras|mentirosos)\b',
    r'\b(sinverguenza|delincuente|delincuentes)\b',
    r'\b(cierren|cierre)\b',
    r'\b(mier[cd]a|jod[eid]|diablos|carajo|imbecil|idiota)\b',
    r'[A-Z]{5,}',           # 5+ consecutive caps (shouting)
    r'[A-Z\s]{10,}',        # 10+ caps with spaces
    r'[!?]{2,}',            # Multiple punctuation
    r'!!!',                 # Triple exclamation
    r'[A-Z\s]{5,}!+',       # Caps + exclamation combo
]
```

---

## 4. CHURN RISK CONFIGURATION

### 4.1 Risk Level Thresholds

```python
THRESHOLDS = {
    'critical': 80,  # >= 80 = CRITICAL
    'high': 60,      # >= 60 = HIGH
    'medium': 40,    # >= 40 = MEDIUM
    # < 40 = LOW
}
```

### 4.2 Score Weights

```python
WEIGHTS = {
    'user_score': {
        'max': 50,
        'ranges': {
            (0, 1): 50,   # Score 0-1: Maximum risk
            (2, 2): 45,   # Score 2: Very high risk
            (3, 3): 35,   # Score 3: High risk
            (4, 4): 25,   # Score 4: Elevated risk
            (5, 5): 15,   # Score 5: Moderate risk
            (6, 6): 8,    # Score 6: Low-moderate risk
            (7, 7): 3,    # Score 7: Minimal risk
            (8, 10): 0,   # Score 8-10: No risk from score
        }
    },
    'exit_threat': {
        'weight': 30,
        'override_min': 50,  # Forces minimum MEDIUM risk
    },
    'competitor_mention': {
        'weight': 10,
        'boost_with_exit': 5,
    },
    'technical_failure': {
        'weight': 20,
        'override_min': 60,  # Forces minimum HIGH risk
    },
    'recurring_issue': {
        'weight': 15,
    },
    'cost_concern': {
        'weight': 10,
        'boost_with_exit': 5,
    },
    'sentiment_alignment': {
        'weight': 10,
        'threshold': 0.50,
    },
    'high_emotion': {
        'weight': 5,
    },
}
```

### 4.3 Special Rules

```python
SPECIAL_RULES = {
    'high_score_with_exit': {
        'condition': 'score >= 8 AND has_exit',
        'minimum_score': 50,  # MEDIUM risk minimum
        'rationale': 'Exit threat overrides positive score'
    },
    'low_score_with_failure': {
        'condition': 'score <= 4 AND has_failure',
        'minimum_score': 70,  # HIGH risk minimum
        'rationale': 'Service failure + dissatisfaction = imminent churn'
    },
    'triple_threat': {
        'condition': 'has_exit AND has_competitor AND has_cost',
        'minimum_score': 85,  # CRITICAL risk
        'rationale': 'Customer actively shopping competitors'
    },
    'escalation_pattern': {
        'condition': 'has_recurring AND has_exit',
        'multiplier': 1.15,  # Boost 15%
        'rationale': 'Unresolved issues lead to exit'
    },
}
```

---

## 5. TASK STATE MACHINE

### 5.1 Task Status

```python
class TaskStatus:
    PENDING = "pending"
    STARTED = "started"
    PROCESSING = "processing"
    RETRY = "retry"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"
    TIMEOUT = "timeout"

    ACTIVE_STATUSES = {PENDING, STARTED, PROCESSING, RETRY}
    TERMINAL_STATUSES = {COMPLETED, FAILED, CANCELLED, TIMEOUT}
```

### 5.2 Upload Status Workflow

```python
UPLOAD_WORKFLOW = [
    "uploaded",      # 0% - File received
    "validating",    # 14% - Schema validation
    "converting",    # 28% - Format conversion
    "caching",       # 42% - Cache storage
    "queued",        # 56% - In processing queue
    "processing",    # 70% - AI analysis
    "completed",     # 100% - Done
]
```

### 5.3 Analysis Status (Fine-grained)

```python
class AnalysisStatus:
    INITIALIZING = "initializing"
    LOADING_DATA = "loading_data"
    PREPROCESSING = "preprocessing"
    ANALYZING = "analyzing"
    GENERATING_INSIGHTS = "generating_insights"
    EXPORTING = "exporting"
    COMPLETED = "completed"
    FAILED = "failed"
```

---

## 6. QUALITY FLAGS TAXONOMY

### 6.1 Quality Flags

| Flag | Trigger | Spanish Translation |
|------|---------|---------------------|
| VERY_SHORT | word_count <= 3 | Muy Corto |
| GENERIC | word_count <= 5 AND contains generic keyword | Generico |
| NO_CONTENT | empty OR length < 3 chars | Sin Contenido |
| NEEDS_REVIEW | requires_human_review = true | Necesita Revision |

### 6.2 Generic Keywords

```python
GENERIC_KEYWORDS = [
    'bien', 'mal', 'bueno', 'malo', 'ok', 'excelente', 'terrible',
    'good', 'bad', 'excellent', 'terrible', 'fine',
    'bom', 'ruim', 'terrivel'  # Portuguese
]
```

### 6.3 Analysis Tier (Simplified)

All comments receive `FULL_AI` analysis (GPT-4o-mini).
Previous tiers (BASIC_AI, FREE) have been removed.

---

## 7. COLUMN NAME SYNONYMS (SCHEMA DETECTION)

### 7.1 Score Column Patterns

```python
SCORE_PATTERNS = {
    "primary": ["nota", "score", "rating"],
    "secondary": [
        "calificacion", "puntuacion", "nps", "valor", "rate",
        "stars", "estrellas", "satisfaction", "satisfaccion",
        "promoter", "promotores", "detractor", "detractores"
    ],
    "semantic": [
        "net promoter score", "customer score", "rating score",
        "feedback score", "satisfaction score"
    ]
}
```

### 7.2 Comment Column Patterns

```python
COMMENT_PATTERNS = {
    "primary": ["comentario", "comment", "feedback"],
    "secondary": [
        "comentario final", "comentario_final", "comentarios",
        "texto", "text", "observacion", "observaciones",
        "detalle", "detalles", "detail", "review", "reviews",
        "opinion", "opiniones", "mensaje", "message",
        "respuesta", "response", "customer feedback", "customer comment"
    ],
    "semantic": [
        "free text", "open text", "verbatim", "customer voice", "feedback text"
    ]
}
```

### 7.3 Confidence Thresholds

```python
EXACT_MATCH_CONFIDENCE = 1.0
HIGH_CONFIDENCE_THRESHOLD = 0.85
MEDIUM_CONFIDENCE_THRESHOLD = 0.70
LOW_CONFIDENCE_THRESHOLD = 0.60
```

### 7.4 Matching Algorithm

1. Exact match with primary patterns -> 1.0 confidence
2. Exact match with secondary patterns -> 0.95 confidence
3. Fuzzy match (rapidfuzz) with primary -> ratio if >= 0.85
4. Contains semantic pattern -> 0.80 + length ratio
5. Fuzzy match with secondary -> ratio * 0.90 if >= 0.70
6. Partial match (contains primary) -> 0.70 + length ratio

---

## 8. SPANISH STOPWORDS

```python
SPANISH_STOPWORDS = {
    # Articles
    'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',

    # Prepositions
    'a', 'ante', 'bajo', 'con', 'contra', 'de', 'desde', 'durante',
    'en', 'entre', 'hacia', 'hasta', 'mediante', 'para', 'por',
    'segun', 'sin', 'sobre', 'tras',

    # Pronouns
    'yo', 'tu', 'el', 'ella', 'usted', 'nosotros', 'nosotras',
    'vosotros', 'vosotras', 'ellos', 'ellas', 'ustedes',
    'me', 'te', 'se', 'le', 'lo', 'nos', 'os', 'les',
    'mi', 'mis', 'su', 'sus', 'nuestro', 'nuestra',

    # Conjunctions
    'y', 'e', 'o', 'u', 'que', 'como', 'si', 'porque',

    # Common verbs
    'ser', 'estar', 'haber', 'tener', 'hacer', 'ir', 'poder', 'decir',
    'es', 'esta', 'son', 'estan', 'fue', 'era', 'sera',
    'ha', 'he', 'han', 'hay',

    # Other common words
    'del', 'al', 'cual', 'donde', 'cuando', 'quien', 'cuyo',
    'este', 'ese', 'aquel', 'esta', 'esa', 'aquella',
    'otro', 'otra', 'otros', 'otras',
    'mismo', 'misma', 'mismos', 'mismas',
    'tanto', 'tanta', 'tantos', 'tantas',
    'todo', 'toda', 'todos', 'todas',
    'mucho', 'mucha', 'muchos', 'muchas',
    'poco', 'poca', 'pocos', 'pocas',
    'mas', 'menos', 'ya', 'aun', 'tambien', 'tampoco',
}

# Preserve for sentiment analysis (don't filter)
PRESERVE_FOR_SENTIMENT = {
    'muy', 'mucho', 'poco', 'bastante', 'demasiado',
    'no', 'nunca', 'jamas', 'sin', 'nada'
}
```

---

## 9. OUTPUT SCHEMA (36 COLUMNS)

### 9.1 Column Groups

**GROUP 1: Primary Review Columns (10)**
- User Score
- Customer Comment
- AI Sentiment (Sentimiento IA)
- Analysis Score
- Score Source
- Sentiment Category
- Emotion
- Churn Risk
- Review Priority Score
- Pain Point Category (Primary)

**GROUP 2: Secondary Analysis Columns (7)**
- Pain Point Category (Secondary)
- Pain Point Keywords
- Sentiment Score Alignment
- Actionability Score
- Word Count
- Has Deep Insights
- Deep Insights JSON

**GROUP 3: Duplicate Detection (5)**
- Is Duplicate
- Duplicate Count
- Duplicate Group ID
- First Occurrence ID
- Is First Occurrence

**GROUP 4: Quality Control (3)**
- Quality Flags
- Analysis Tier
- Problemas Detectados

**GROUP 5: AI Correction Details (4)**
- Original User Score
- Sentiment Score (Before Discrepancy Check)
- Discrepancy Flag
- Discrepancy Explanation

**GROUP 6: Technical Scores (2)**
- Sentiment Score (GPT-4o-mini)
- Confidence Score

**GROUP 7: Behavioral Flags (6)**
- Has_Exit_Threat
- Has_Competitor_Mention
- Has_Technical_Failure
- Has_Recurring_Issue
- Has_Cost_Concern
- Has_High_Emotion

---

## APPENDIX A: IMPLEMENTATION NOTES FOR ARROW+RAY

### A.1 Data Structures

Replace pandas DataFrames with:
- **PyArrow Tables** for columnar storage
- **Ray Datasets** for distributed processing

### A.2 Batch Processing

```python
# Current (pandas + Celery)
df.apply(lambda row: analyze(row), axis=1)

# Target (Arrow + Ray)
@ray.remote
def analyze_batch(batch: pa.RecordBatch) -> pa.RecordBatch:
    # Process batch
    return result_batch

ds = ray.data.from_arrow(table)
result = ds.map_batches(analyze_batch, batch_size=100)
```

### A.3 Caching

Replace Redis with:
- **Ray Object Store** for hot cache
- **Parquet files** for cold cache

### A.4 Task Queue

Replace Celery with:
- **Ray Tasks** for async processing
- **Ray Actors** for stateful workers

---

**Document Version:** 1.0
**Extracted From:** customer-feedback-app v3.10.0
**Target Stack:** Arrow + Ray + Docker + Cloudflare
