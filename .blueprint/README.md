# Feedback-Arrow Blueprint Hub

A collection of specifications for building customer feedback analysis systems using AI-powered NLP and columnar data processing.

---

## Quick Navigation

| Directory | Purpose | Start Here |
|-----------|---------|------------|
| [core/](core/) | Business domain logic (stack-agnostic) | [BUSINESS_DOMAIN.md](core/BUSINESS_DOMAIN.md) |
| [contracts/](contracts/) | Interface specifications | [API_CONTRACT.md](contracts/API_CONTRACT.md) |
| [implementations/](implementations/) | Stack-specific blueprints | [rust-arrow/](implementations/rust-arrow/) |
| [operations/](operations/) | Security, multi-tenancy, observability | [SECURITY_SPEC.md](operations/SECURITY_SPEC.md) |
| [architecture/](architecture/) | Design decisions & strategy | [TARGET_ARCHITECTURE.md](architecture/TARGET_ARCHITECTURE.md) |
| [schemas/](schemas/) | Data structures & prompts | [ANALYSIS_SCHEMA_CONFIG.md](schemas/ANALYSIS_SCHEMA_CONFIG.md) |
| [testing/](testing/) | Test strategy & golden datasets | [TESTING_STRATEGY.md](testing/TESTING_STRATEGY.md) |

---

## Directory Structure

```
blueprint/
├── core/                        # WHAT the system does (stack-agnostic)
│   ├── BUSINESS_DOMAIN.md       # Emotions, churn, NPS, pain points, scoring
│   ├── PIPELINE_DEFINITION.md   # DAG structure, 15 nodes, data flow
│   ├── VALIDATION_RULES.md      # Input/output validation
│   └── LANGUAGE_PACKS.md        # i18n, Spanish/English resources
│
├── contracts/                   # HOW to interface (implementation-agnostic)
│   ├── API_CONTRACT.md          # REST API (OpenAPI 3.0)
│   ├── LLM_PROVIDER_CONTRACT.md # LLM abstraction, routing strategies
│   ├── EXPORT_CONTRACT.md       # Parquet/CSV/JSON output formats
│   └── STATE_STORE_CONTRACT.md  # Caching interface
│
├── implementations/             # HOW to build (stack-specific)
│   ├── rust-arrow/              # Rust + Arrow + Tokio + Axum
│   │   └── OVERVIEW.md          # Crate architecture, llama-server subprocess
│   │
│   └── python-dask/             # Python + Dask + Polars (legacy reference)
│       ├── COMPUTE_GRAPH_SPEC.md
│       ├── COMPUTE_NODES_SPEC.md
│       ├── DI_SPEC.md
│       └── CONFIG_SPEC.md
│
├── operations/                  # HOW to run (cross-stack)
│   ├── SECURITY_SPEC.md         # Auth, RBAC, API keys (fa_live_xxx)
│   ├── MULTI_TENANCY_SPEC.md    # Org/workspace/project, tier quotas
│   └── OBSERVABILITY_SPEC.md    # Metrics, tracing, logging
│
├── architecture/                # WHY decisions were made
│   ├── TARGET_ARCHITECTURE.md   # High-level design
│   ├── DEPENDENCY_GRAPH.md      # Interface relationships (6 levels)
│   ├── STRATEGY.md              # Build vs buy, vendor choices
│   └── BLINDSPOTS.md            # Known gaps, risks, mitigations
│
├── schemas/                     # Data structure definitions
│   ├── ANALYSIS_SCHEMA_CONFIG.md   # LLM prompt configurations
│   └── PROMPT_SCHEMA_CONFIG.md     # Prompt templates
│
├── testing/                     # Quality assurance
│   ├── TESTING_STRATEGY.md      # Test pyramid, mocks, fixtures
│   └── golden-datasets/         # Expected outputs for validation
│
└── _archive/                    # Superseded docs (reference only)
```

---

## Reading Order

### For Product Understanding
1. `core/BUSINESS_DOMAIN.md` - What the system analyzes (emotions, churn, NPS)
2. `core/PIPELINE_DEFINITION.md` - How data flows through the DAG
3. `contracts/API_CONTRACT.md` - How clients interact with the system

### For Implementation
1. `architecture/TARGET_ARCHITECTURE.md` - High-level design
2. `architecture/DEPENDENCY_GRAPH.md` - Interface relationships
3. `implementations/rust-arrow/OVERVIEW.md` - Rust-specific implementation plan
4. `contracts/LLM_PROVIDER_CONTRACT.md` - LLM integration requirements

### For Operations
1. `operations/SECURITY_SPEC.md` - Authentication & authorization
2. `operations/MULTI_TENANCY_SPEC.md` - Tenant isolation & quotas
3. `operations/OBSERVABILITY_SPEC.md` - Monitoring & alerting

---

## Implementation Status

| Implementation | Status | Primary Use Case |
|----------------|--------|------------------|
| **rust-arrow** | Active | Production deployment, single-binary |
| **python-dask** | Reference | Legacy reference, scale-out patterns |

---

## Key Concepts

### Entity IDs
```
org_01hqx5k8n7gm4r2p3j6c9b0a      # Organization
ws_01hqx5k8n7gm4r2p3j6c9b0a       # Workspace
proj_01hqx5k8n7gm4r2p3j6c9b0a     # Project
analysis_01hqx5k8n7gm4r2p3j6c9b0a # Analysis job
```

### API Keys
```
fa_live_aBcDeFgHiJkLmNoPqRsTuVwXyZ012345   # Production
fa_test_aBcDeFgHiJkLmNoPqRsTuVwXyZ012345   # Testing
```

### Error Codes
```
FA-AUTH-001   # Authentication failed
FA-RATE-001   # Rate limit exceeded
FA-VAL-001    # Validation error
FA-LLM-001    # LLM provider unavailable
```

### Tier Quotas

| Tier | Rate Limit | Daily Rows | Storage | Concurrent Jobs |
|------|------------|------------|---------|-----------------|
| Free | 10/min | 1,000 | 100MB | 1 |
| Pro | 100/min | 100,000 | 10GB | 5 |
| Enterprise | 1000/min | Unlimited | 1TB | 50 |

---

## Contributing

When adding a new implementation:
1. Create `implementations/{stack-name}/OVERVIEW.md`
2. Reference contracts from `contracts/`
3. Follow domain logic from `core/`
4. Update this README with the new implementation

---

**Version:** 2.0.0
**Updated:** December 2025
