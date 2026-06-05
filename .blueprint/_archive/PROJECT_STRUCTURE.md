# Project Structure Specification

**Status:** Defined
**Date:** 2025-12-15
**Covers Gap:** #5 - Project Scaffolding

---

## Overview

- **Package Manager:** uv
- **Python:** 3.12+ (compatible with 3.10+)
- **Data Layer:** PyArrow
- **Testing:** pytest
- **Type Checking:** pyright

---

## Directory Structure

```
feedback-arrow/
├── pyproject.toml              # Project config, dependencies
├── uv.lock                     # Lock file (auto-generated)
├── .python-version             # Python version for uv
├── README.md
├── .gitignore
├── .env.example                # Environment template
│
├── src/
│   └── feedback_arrow/
│       ├── __init__.py
│       ├── __main__.py         # CLI entry point
│       ├── config.py           # Configuration loader
│       │
│       ├── providers/          # LLM Provider implementations
│       │   ├── __init__.py
│       │   ├── interface.py    # ILLMProvider ABC
│       │   ├── ollama.py
│       │   ├── vllm.py
│       │   ├── openai.py
│       │   ├── anthropic.py
│       │   └── router.py       # Provider routing strategies
│       │
│       ├── analysis/           # Core analysis logic
│       │   ├── __init__.py
│       │   ├── orchestrator.py # Batch orchestration
│       │   ├── sentiment.py
│       │   ├── churn.py
│       │   ├── nps.py
│       │   └── pain_points.py
│       │
│       ├── export/             # Export system
│       │   ├── __init__.py
│       │   ├── formats/
│       │   │   ├── __init__.py
│       │   │   ├── interface.py  # IExportFormat ABC
│       │   │   ├── parquet.py
│       │   │   ├── csv.py
│       │   │   └── json.py
│       │   └── destinations/
│       │       ├── __init__.py
│       │       ├── interface.py  # IExportDestination ABC
│       │       ├── local.py
│       │       ├── s3.py
│       │       └── gdrive.py
│       │
│       ├── cache/              # Caching layer
│       │   ├── __init__.py
│       │   ├── interface.py    # ICache ABC
│       │   ├── memory.py       # Hot cache
│       │   └── disk.py         # Cold cache
│       │
│       ├── language/           # Language pack loader
│       │   ├── __init__.py
│       │   └── loader.py
│       │
│       ├── schemas/            # Pydantic models
│       │   ├── __init__.py
│       │   ├── analysis.py     # Analysis output schema
│       │   ├── config.py       # Configuration schema
│       │   └── prompts.py      # Prompt templates
│       │
│       └── utils/
│           ├── __init__.py
│           ├── arrow.py        # Arrow utilities
│           └── logging.py
│
├── language_packs/             # Language-specific data
│   ├── _schema/
│   │   └── pack_schema.json
│   ├── es/
│   │   ├── manifest.json
│   │   ├── sentiment.json
│   │   ├── keywords.json
│   │   ├── patterns.json
│   │   ├── negations.json
│   │   └── thresholds.json
│   ├── en/
│   │   └── ...
│   └── index.json
│
├── tests/
│   ├── __init__.py
│   ├── conftest.py             # Shared fixtures
│   ├── test_providers/
│   ├── test_analysis/
│   ├── test_export/
│   └── test_integration/
│
├── blueprint/                  # Existing specs (this folder)
│   └── ...
│
└── scripts/                    # Dev/deployment scripts
    ├── setup.sh
    └── validate_packs.py
```

---

## pyproject.toml

```toml
[project]
name = "feedback-arrow"
version = "0.1.0"
description = "Arrow-native feedback analysis with pluggable LLM providers"
readme = "README.md"
requires-python = ">=3.10"
license = { text = "MIT" }
authors = [{ name = "Your Name" }]

dependencies = [
    "pyarrow>=14.0.0",
    "pydantic>=2.0.0",
    "httpx>=0.25.0",
    "python-dotenv>=1.0.0",
]

[project.optional-dependencies]
# LLM Providers
ollama = ["ollama>=0.1.0"]
openai = ["openai>=1.0.0"]
anthropic = ["anthropic>=0.18.0"]

# Export destinations
s3 = ["boto3>=1.34.0"]
gdrive = ["google-api-python-client>=2.0.0", "google-auth>=2.0.0"]

# Development
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
    "pyright>=1.1.350",
    "ruff>=0.2.0",
]

# All providers
all = [
    "feedback-arrow[ollama,openai,anthropic,s3,gdrive,dev]"
]

[project.scripts]
feedback-arrow = "feedback_arrow.__main__:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/feedback_arrow"]

[tool.pyright]
pythonVersion = "3.10"
typeCheckingMode = "standard"
venvPath = "."
venv = ".venv"

[tool.ruff]
target-version = "py310"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "UP"]

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
```

---

## .python-version

```
3.12
```

---

## .gitignore

```gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
.venv/
venv/
.eggs/
*.egg-info/

# uv
uv.lock

# Environment
.env
.env.local

# IDE
.vscode/
.idea/

# Testing
.pytest_cache/
.coverage
htmlcov/

# Build
dist/
build/

# Exports
exports/

# OS
.DS_Store
Thumbs.db
```

---

## .env.example

```bash
# LLM Providers
OLLAMA_HOST=http://localhost:11434
OPENAI_API_KEY=
ANTHROPIC_API_KEY=

# Export Destinations
S3_BUCKET=
S3_ENDPOINT_URL=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

# Google Drive (path to service account JSON)
GDRIVE_CREDENTIALS_PATH=

# Defaults
DEFAULT_PROVIDER=ollama
DEFAULT_MODEL=llama3.2
DEFAULT_LANGUAGE=es
```

---

## Quick Start Commands

```bash
# Install uv (if not installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create project and venv
uv venv
source .venv/bin/activate

# Install dependencies
uv pip install -e ".[dev]"

# Install with specific provider
uv pip install -e ".[ollama,dev]"

# Install all
uv pip install -e ".[all]"

# Run tests
pytest

# Type check
pyright

# Lint
ruff check src/

# Run CLI
feedback-arrow --help
```

---

## Entry Point (__main__.py)

```python
"""CLI entry point for feedback-arrow."""
import argparse
import sys


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="feedback-arrow",
        description="Arrow-native feedback analysis"
    )
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s 0.1.0"
    )
    subparsers = parser.add_subparsers(dest="command")

    # analyze command
    analyze = subparsers.add_parser("analyze", help="Run analysis")
    analyze.add_argument("input", help="Input file (CSV, Parquet, JSON)")
    analyze.add_argument("-o", "--output", help="Output path")
    analyze.add_argument("-f", "--format", default="parquet")
    analyze.add_argument("-p", "--provider", default="ollama")
    analyze.add_argument("-l", "--language", default="es")

    # validate command
    validate = subparsers.add_parser("validate", help="Validate language pack")
    validate.add_argument("pack", help="Language code to validate")

    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        return 0

    # Dispatch to command handlers
    # TODO: Implement command handlers

    return 0


if __name__ == "__main__":
    sys.exit(main())
```

---

## Module Init Pattern

Each `__init__.py` should expose the public API:

```python
# src/feedback_arrow/providers/__init__.py
from .interface import ILLMProvider
from .router import ProviderRouter

__all__ = ["ILLMProvider", "ProviderRouter"]
```

---

## Python 3.10 Compatibility Notes

Avoid these 3.11+ features to maintain 3.10 compatibility:
- `ExceptionGroup` (3.11)
- `TaskGroup` (3.11)
- `tomllib` (3.11) - use `tomli` instead
- Type parameter syntax `def f[T](x: T)` (3.12) - use `TypeVar`

Use these instead:
```python
# Instead of 3.12 syntax
from typing import TypeVar
T = TypeVar("T")
def process(item: T) -> T: ...

# Instead of tomllib
try:
    import tomllib
except ImportError:
    import tomli as tomllib
```

---

**All gaps addressed. Ready to implement.**
