# Testing Specification

**Purpose:** Test strategy, mocks, fixtures, CI/CD integration
**Status:** Authoritative
**Date:** 2025-12-19

---

## 1. Test Pyramid

### 1.1 Distribution

```
                    ┌─────────────┐
                    │    E2E      │  10% - Full stack validation
                    │   Tests     │
                    ├─────────────┤
                    │ Integration │  20% - Component interaction
                    │   Tests     │
                    ├─────────────┤
                    │    Unit     │  70% - Pure function logic
                    │   Tests     │
                    └─────────────┘
```

| Type | Coverage Target | Execution Time | External Deps |
|------|-----------------|----------------|---------------|
| Unit | 80% lines | < 5 sec | None |
| Integration | Critical paths | < 60 sec | In-memory/Docker |
| E2E | Happy paths | < 5 min | Full stack |
| Performance | Benchmarks | ~ 10 min | Full stack |

### 1.2 Test Categories

```python
# pytest markers
pytest.ini:
markers =
    unit: Pure function tests, no I/O
    integration: Tests with real dependencies (database, cache)
    e2e: Full stack end-to-end tests
    slow: Tests taking > 1 second
    llm: Tests requiring LLM provider (mock by default)
    golden: Tests against golden datasets
```

**Running specific categories:**
```bash
# Unit tests only (fast, CI)
pytest -m unit

# Integration tests (needs Docker)
pytest -m integration

# E2E tests (needs full stack)
pytest -m e2e

# Exclude slow tests
pytest -m "not slow"

# Golden dataset tests
pytest -m golden
```

---

## 2. Mock Implementations

### 2.1 MockLLMProvider

```python
class MockLLMProvider(ILLMProvider):
    """Deterministic LLM provider for testing"""

    def __init__(
        self,
        responses: Optional[Dict[str, AnalysisResult]] = None,
        latency_ms: int = 0,
        failure_rate: float = 0.0
    ):
        self.responses = responses or self._default_responses()
        self.latency_ms = latency_ms
        self.failure_rate = failure_rate
        self.call_history: List[AnalysisRequest] = []

    def _default_responses(self) -> Dict[str, AnalysisResult]:
        """Default response patterns based on keywords"""
        return {
            "positive_keywords": ["love", "great", "excellent", "amazing", "wonderful"],
            "negative_keywords": ["hate", "terrible", "awful", "worst", "horrible"],
            "churn_keywords": ["cancel", "leaving", "switching", "competitor"],
        }

    async def analyze_batch(self, request: AnalysisRequest) -> List[AnalysisResult]:
        self.call_history.append(request)

        if self.latency_ms > 0:
            await asyncio.sleep(self.latency_ms / 1000)

        if random.random() < self.failure_rate:
            raise LLMProviderError("Simulated failure")

        results = []
        for comment in request.comments.to_pylist():
            result = self._analyze_comment(comment, request.language)
            results.append(result)

        return results

    def _analyze_comment(self, comment: str, language: str) -> AnalysisResult:
        """Deterministic analysis based on keywords"""
        comment_lower = comment.lower()

        # Sentiment
        pos_count = sum(1 for kw in self.responses["positive_keywords"] if kw in comment_lower)
        neg_count = sum(1 for kw in self.responses["negative_keywords"] if kw in comment_lower)

        if pos_count > neg_count:
            sentiment = "positive"
            sentiment_score = 0.7 + (pos_count * 0.05)
        elif neg_count > pos_count:
            sentiment = "negative"
            sentiment_score = 0.3 - (neg_count * 0.05)
        else:
            sentiment = "neutral"
            sentiment_score = 0.5

        # Churn risk
        churn_keywords = sum(1 for kw in self.responses["churn_keywords"] if kw in comment_lower)
        churn_risk = min(churn_keywords * 30, 100)

        return AnalysisResult(
            sentiment=sentiment,
            sentiment_score=min(max(sentiment_score, 0), 1),
            churn_risk=churn_risk,
            emotions=self._detect_emotions(comment_lower),
            pain_points=self._detect_pain_points(comment_lower),
            key_insight=f"Mock insight for: {comment[:50]}...",
            confidence=0.85
        )

    def get_capabilities(self) -> ProviderCapabilities:
        return ProviderCapabilities(
            provider_id="mock",
            supports_structured_output=True,
            supports_batch=True,
            max_context_tokens=8192,
            latency_p50_ms=self.latency_ms,
            cost_per_1k_input=0.0,
            cost_per_1k_output=0.0
        )

    async def health_check(self) -> bool:
        return self.failure_rate < 1.0

    def assert_called_with(self, expected_comments: List[str]) -> None:
        """Test assertion helper"""
        actual_comments = []
        for req in self.call_history:
            actual_comments.extend(req.comments.to_pylist())
        assert actual_comments == expected_comments, f"Expected {expected_comments}, got {actual_comments}"

    def reset(self) -> None:
        """Reset call history"""
        self.call_history.clear()
```

### 2.1.1 Provider Interchangeability Tests

All LLM nodes must work identically regardless of which provider is injected. These tests verify the multi-provider, local-first architecture defined in `LLM_PROVIDER_CONTRACT.md`.

```python
class TestProviderInterchangeability:
    """Verify nodes work with any ILLMProvider implementation"""

    @pytest.fixture(params=["mock", "ollama_stub", "openai_stub"])
    def provider(self, request) -> ILLMProvider:
        """Parameterized fixture for provider testing"""
        if request.param == "mock":
            return MockLLMProvider()
        elif request.param == "ollama_stub":
            return OllamaStub(responses=STANDARD_RESPONSES)
        elif request.param == "openai_stub":
            return OpenAIStub(responses=STANDARD_RESPONSES)

    def test_sentiment_node_provider_agnostic(self, provider: ILLMProvider):
        """Same input produces consistent output structure across providers"""
        node = LLMSentimentNode()
        context = ExecutionContext(llm_provider=provider)

        result = node.transform(SAMPLE_TABLE, context)

        # Structure must be identical regardless of provider
        assert "ai_sentiment_score" in result.table.column_names
        assert "ai_sentiment_category" in result.table.column_names
        assert result.table.num_rows == SAMPLE_TABLE.num_rows

    def test_provider_failover(self):
        """Verify router fails over to next provider on error"""
        failing_provider = MockLLMProvider(failure_rate=1.0)
        backup_provider = MockLLMProvider(failure_rate=0.0)

        router = LLMRouter(
            providers=[failing_provider, backup_provider],
            strategy="failover"
        )

        # Should use backup after primary fails
        result = await router.analyze_batch(SAMPLE_REQUEST)
        assert result is not None
        assert backup_provider.call_history  # Backup was called

    def test_local_first_routing(self):
        """Verify local providers are preferred over cloud"""
        ollama = MockLLMProvider()  # Simulates local
        openai = MockLLMProvider()  # Simulates cloud

        router = LLMRouter(
            providers=[ollama, openai],
            strategy="local_first",
            local_providers=["ollama"]
        )

        await router.analyze_batch(SAMPLE_REQUEST)

        assert ollama.call_history  # Local was used
        assert not openai.call_history  # Cloud was not used
```

### 2.2 MockCache

```python
class MockCache(ICache):
    """In-memory cache for testing"""

    def __init__(self):
        self._store: Dict[str, Tuple[bytes, Optional[datetime]]] = {}
        self.get_calls: List[str] = []
        self.set_calls: List[Tuple[str, bytes]] = []

    async def get(self, key: str) -> Optional[bytes]:
        self.get_calls.append(key)
        entry = self._store.get(key)
        if entry is None:
            return None
        value, expires_at = entry
        if expires_at and datetime.utcnow() > expires_at:
            del self._store[key]
            return None
        return value

    async def set(self, key: str, value: bytes, ttl: Optional[int] = None) -> None:
        self.set_calls.append((key, value))
        expires_at = None
        if ttl:
            expires_at = datetime.utcnow() + timedelta(seconds=ttl)
        self._store[key] = (value, expires_at)

    async def delete(self, key: str) -> bool:
        if key in self._store:
            del self._store[key]
            return True
        return False

    async def clear(self) -> None:
        self._store.clear()

    def get_stats(self) -> Dict[str, int]:
        return {
            "size": len(self._store),
            "get_calls": len(self.get_calls),
            "set_calls": len(self.set_calls),
            "hit_rate": self._calculate_hit_rate()
        }

    def _calculate_hit_rate(self) -> float:
        if not self.get_calls:
            return 0.0
        hits = sum(1 for key in self.get_calls if key in self._store)
        return hits / len(self.get_calls)

    def reset(self) -> None:
        self._store.clear()
        self.get_calls.clear()
        self.set_calls.clear()
```

### 2.3 MockStorage

```python
class MockStorage(IStorage):
    """In-memory storage for testing"""

    def __init__(self):
        self._files: Dict[str, bytes] = {}

    async def read(self, path: str) -> bytes:
        if path not in self._files:
            raise FileNotFoundError(f"Mock file not found: {path}")
        return self._files[path]

    async def write(self, path: str, data: bytes) -> None:
        self._files[path] = data

    async def delete(self, path: str) -> bool:
        if path in self._files:
            del self._files[path]
            return True
        return False

    async def exists(self, path: str) -> bool:
        return path in self._files

    async def list(self, prefix: str) -> List[str]:
        return [p for p in self._files.keys() if p.startswith(prefix)]

    async def read_table(self, path: str) -> pa.Table:
        """Read Arrow table from mock storage"""
        data = await self.read(path)
        reader = pa.ipc.open_file(io.BytesIO(data))
        return reader.read_all()

    async def write_table(self, path: str, table: pa.Table) -> None:
        """Write Arrow table to mock storage"""
        sink = io.BytesIO()
        with pa.ipc.new_file(sink, table.schema) as writer:
            writer.write_table(table)
        await self.write(path, sink.getvalue())

    def seed(self, files: Dict[str, bytes]) -> None:
        """Seed storage with test files"""
        self._files.update(files)

    def clear(self) -> None:
        self._files.clear()
```

### 2.4 MockSecretStore

```python
class MockSecretStore(ISecretStore):
    """Dict-based secret store for testing"""

    def __init__(self, secrets: Optional[Dict[str, str]] = None):
        self._secrets = secrets or {
            "OPENAI_API_KEY": "sk-test-mock-key",
            "ANTHROPIC_API_KEY": "sk-ant-test-mock-key",
            "DATABASE_PASSWORD": "test-password",
        }

    async def get_secret(self, name: str) -> str:
        if name not in self._secrets:
            raise SecretNotFoundError(f"Secret not found: {name}")
        return self._secrets[name]

    async def set_secret(self, name: str, value: str) -> None:
        self._secrets[name] = value

    async def delete_secret(self, name: str) -> bool:
        if name in self._secrets:
            del self._secrets[name]
            return True
        return False

    def seed(self, secrets: Dict[str, str]) -> None:
        """Add test secrets"""
        self._secrets.update(secrets)
```

### 2.5 MockPersistence

```python
class MockPersistence(IPersistence):
    """In-memory persistence for testing"""

    def __init__(self):
        self._tables: Dict[str, List[Dict]] = {}
        self._id_counters: Dict[str, int] = {}

    async def save(self, table: str, record: Dict) -> str:
        if table not in self._tables:
            self._tables[table] = []
            self._id_counters[table] = 0

        # Generate ID if not provided
        if "id" not in record:
            self._id_counters[table] += 1
            record["id"] = f"{table}_{self._id_counters[table]}"

        self._tables[table].append(record.copy())
        return record["id"]

    async def find(self, table: str, query: Dict) -> List[Dict]:
        if table not in self._tables:
            return []

        results = []
        for record in self._tables[table]:
            if self._matches(record, query):
                results.append(record.copy())
        return results

    async def find_one(self, table: str, query: Dict) -> Optional[Dict]:
        results = await self.find(table, query)
        return results[0] if results else None

    async def update(self, table: str, id: str, changes: Dict) -> bool:
        if table not in self._tables:
            return False

        for record in self._tables[table]:
            if record.get("id") == id:
                record.update(changes)
                return True
        return False

    async def delete(self, table: str, id: str) -> bool:
        if table not in self._tables:
            return False

        original_len = len(self._tables[table])
        self._tables[table] = [r for r in self._tables[table] if r.get("id") != id]
        return len(self._tables[table]) < original_len

    def _matches(self, record: Dict, query: Dict) -> bool:
        for key, value in query.items():
            if key not in record:
                return False
            if isinstance(value, dict):
                # Handle operators like {"$gt": 5}
                if not self._match_operators(record[key], value):
                    return False
            elif record[key] != value:
                return False
        return True

    def _match_operators(self, field_value: Any, operators: Dict) -> bool:
        for op, value in operators.items():
            if op == "$gt" and not (field_value > value):
                return False
            if op == "$gte" and not (field_value >= value):
                return False
            if op == "$lt" and not (field_value < value):
                return False
            if op == "$lte" and not (field_value <= value):
                return False
            if op == "$in" and field_value not in value:
                return False
        return True

    def seed(self, table: str, records: List[Dict]) -> None:
        """Seed table with test data"""
        self._tables[table] = [r.copy() for r in records]

    def clear(self) -> None:
        self._tables.clear()
        self._id_counters.clear()
```

---

## 3. Fixtures & Factories

### 3.1 Pytest Fixtures

```python
# tests/conftest.py

import pytest
from feedback_arrow.config import FeedbackArrowConfig
from feedback_arrow.container import create_test_container

@pytest.fixture
def test_config() -> FeedbackArrowConfig:
    """Default test configuration"""
    return FeedbackArrowConfig(
        env="testing",
        database={"url": "sqlite:///:memory:"},
        cache={"backend": "memory"},
        providers={"default": "mock"},
        analysis={"batch_size": 5}
    )

@pytest.fixture
def container(test_config) -> IContainer:
    """Test container with mocks"""
    return create_test_container(test_config)

@pytest.fixture
def mock_llm() -> MockLLMProvider:
    """Mock LLM provider"""
    return MockLLMProvider()

@pytest.fixture
def mock_cache() -> MockCache:
    """Mock cache"""
    return MockCache()

@pytest.fixture
def mock_persistence() -> MockPersistence:
    """Mock persistence"""
    return MockPersistence()

@pytest.fixture
def fixtures(container) -> TestFixtures:
    """Test fixture factories"""
    return TestFixtures(container)

@pytest.fixture
def tenant_ctx(fixtures) -> TenantContext:
    """Default test tenant context"""
    return fixtures.create_tenant_context()

@pytest.fixture
def sample_input() -> pa.Table:
    """Sample analysis input"""
    return pa.table({
        "id": [1, 2, 3, 4, 5],
        "user_score": [8.5, 3.0, 7.0, 2.0, 9.0],
        "customer_comment": [
            "Great product, love it!",
            "Terrible service, considering canceling",
            "It's okay, nothing special",
            "Worst experience ever",
            "Amazing support team!"
        ]
    })
```

### 3.2 Factory Classes

```python
class TenantFactory:
    """Factory for creating test tenants"""

    _counter = 0

    @classmethod
    def create(
        cls,
        org_id: Optional[str] = None,
        workspace_id: Optional[str] = None,
        tier: Tier = Tier.PRO,
        **overrides
    ) -> TenantContext:
        cls._counter += 1

        return TenantContext(
            org_id=org_id or f"org_test{cls._counter:04d}",
            workspace_id=workspace_id or f"ws_test{cls._counter:04d}",
            project_id=overrides.get("project_id"),
            user_id=overrides.get("user_id", f"usr_test{cls._counter:04d}"),
            api_key_id=overrides.get("api_key_id"),
            tier=tier,
            quotas=QuotaLimits.for_tier(tier)
        )

    @classmethod
    def create_free(cls, **overrides) -> TenantContext:
        return cls.create(tier=Tier.FREE, **overrides)

    @classmethod
    def create_enterprise(cls, **overrides) -> TenantContext:
        return cls.create(tier=Tier.ENTERPRISE, **overrides)


class DataFactory:
    """Factory for creating test data"""

    COMMENTS_EN = {
        "positive": [
            "Excellent product, highly recommend!",
            "Best purchase I've ever made",
            "Outstanding customer service",
        ],
        "negative": [
            "Very disappointed with quality",
            "Terrible experience, want refund",
            "Product broke after one day",
        ],
        "neutral": [
            "Product is okay, nothing special",
            "It works as described",
            "Average quality for the price",
        ],
        "churn": [
            "Thinking about switching to competitor",
            "Planning to cancel my subscription",
            "Your competitor offers better pricing",
        ]
    }

    COMMENTS_ES = {
        "positive": [
            "Excelente producto, muy recomendado!",
            "La mejor compra que he hecho",
            "Servicio al cliente excepcional",
        ],
        "negative": [
            "Muy decepcionado con la calidad",
            "Experiencia terrible, quiero reembolso",
            "El producto se rompió en un día",
        ],
        "neutral": [
            "El producto está bien, nada especial",
            "Funciona como se describe",
            "Calidad promedio por el precio",
        ],
        "churn": [
            "Estoy pensando en cambiar a la competencia",
            "Voy a cancelar mi suscripción",
            "La competencia ofrece mejor precio",
        ]
    }

    @classmethod
    def create_table(
        cls,
        rows: int = 10,
        language: str = "es",
        sentiment_distribution: Optional[Dict[str, float]] = None
    ) -> pa.Table:
        """Create test analysis input table"""
        if sentiment_distribution is None:
            sentiment_distribution = {"positive": 0.4, "negative": 0.3, "neutral": 0.2, "churn": 0.1}

        comments_pool = cls.COMMENTS_ES if language == "es" else cls.COMMENTS_EN
        comments = []
        scores = []

        for i in range(rows):
            sentiment = random.choices(
                list(sentiment_distribution.keys()),
                weights=list(sentiment_distribution.values())
            )[0]

            comment = random.choice(comments_pool[sentiment])
            comments.append(comment)

            # Score correlated with sentiment
            base_score = {"positive": 8, "negative": 3, "neutral": 5, "churn": 2}[sentiment]
            scores.append(base_score + random.uniform(-1, 1))

        return pa.table({
            "id": list(range(1, rows + 1)),
            "user_score": scores,
            "customer_comment": comments
        })

    @classmethod
    def create_golden_input(cls, dataset_name: str) -> pa.Table:
        """Load golden dataset input"""
        path = Path(__file__).parent / "golden-datasets" / f"{dataset_name}_input.parquet"
        return pq.read_table(path)

    @classmethod
    def create_golden_expected(cls, dataset_name: str) -> pa.Table:
        """Load golden dataset expected output"""
        path = Path(__file__).parent / "golden-datasets" / f"{dataset_name}_expected.parquet"
        return pq.read_table(path)


class JobFactory:
    """Factory for creating test jobs"""

    _counter = 0

    @classmethod
    def create(
        cls,
        tenant_ctx: TenantContext,
        input_data: Optional[pa.Table] = None,
        **overrides
    ) -> JobContext:
        cls._counter += 1

        if input_data is None:
            input_data = DataFactory.create_table()

        return JobContext(
            job_id=overrides.get("job_id", f"job_test{cls._counter:04d}"),
            tenant=tenant_ctx,
            input_data=input_data,
            created_at=datetime.utcnow(),
            status=JobStatus.PENDING
        )
```

### 3.3 Golden Dataset Loaders

```python
class GoldenDataset:
    """Golden dataset for validation testing"""

    def __init__(self, name: str, base_path: Path):
        self.name = name
        self.base_path = base_path
        self._input: Optional[pa.Table] = None
        self._expected: Optional[pa.Table] = None
        self._metadata: Optional[Dict] = None

    @property
    def input(self) -> pa.Table:
        if self._input is None:
            self._input = pq.read_table(self.base_path / f"{self.name}_input.parquet")
        return self._input

    @property
    def expected(self) -> pa.Table:
        if self._expected is None:
            self._expected = pq.read_table(self.base_path / f"{self.name}_expected.parquet")
        return self._expected

    @property
    def metadata(self) -> Dict:
        if self._metadata is None:
            with open(self.base_path / f"{self.name}_metadata.json") as f:
                self._metadata = json.load(f)
        return self._metadata

    @property
    def tolerance(self) -> ToleranceProfile:
        return ToleranceProfile.from_dict(self.metadata.get("tolerance", {}))


class GoldenDatasetRegistry:
    """Registry of all golden datasets"""

    DATASETS = {
        "spanish_nps_basic": "Basic Spanish NPS survey responses",
        "spanish_churn_signals": "Spanish feedback with churn indicators",
        "english_sentiment": "English sentiment analysis dataset",
        "mixed_emotions": "Multi-emotion detection dataset",
    }

    def __init__(self, base_path: Optional[Path] = None):
        self.base_path = base_path or Path(__file__).parent / "golden-datasets"

    def get(self, name: str) -> GoldenDataset:
        if name not in self.DATASETS:
            raise ValueError(f"Unknown dataset: {name}. Available: {list(self.DATASETS.keys())}")
        return GoldenDataset(name, self.base_path)

    def list(self) -> Dict[str, str]:
        return self.DATASETS.copy()

    def load_all(self) -> List[GoldenDataset]:
        return [self.get(name) for name in self.DATASETS]
```

---

## 4. Test Configuration

### 4.1 pytest.ini

```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*

# Markers
markers =
    unit: Pure function tests, no I/O
    integration: Tests with real dependencies
    e2e: Full stack end-to-end tests
    slow: Tests taking > 1 second
    llm: Tests requiring LLM provider
    golden: Tests against golden datasets

# Async
asyncio_mode = auto

# Logging
log_cli = true
log_cli_level = INFO

# Coverage
addopts = --cov=src/feedback_arrow --cov-report=term-missing --cov-report=html

# Parallel
# Use: pytest -n auto
```

### 4.2 Parallel Test Execution

```python
# conftest.py - Parallel test configuration

@pytest.fixture(scope="session")
def worker_id(request):
    """Get pytest-xdist worker id"""
    if hasattr(request.config, "workerinput"):
        return request.config.workerinput["workerid"]
    return "master"

@pytest.fixture
def unique_db_name(worker_id):
    """Unique database name per worker for parallel execution"""
    return f"test_db_{worker_id}"

@pytest.fixture
def isolated_persistence(unique_db_name):
    """Persistence isolated per worker"""
    return DuckDBPersistence(f"duckdb:///:memory:?name={unique_db_name}")
```

### 4.3 Test Database Setup

```python
# conftest.py - Database fixtures

@pytest.fixture(scope="session")
def db_engine():
    """Create test database engine (session scoped)"""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()

@pytest.fixture
def db_session(db_engine):
    """Create test database session (function scoped)"""
    connection = db_engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()

@pytest.fixture
def seeded_db(db_session):
    """Database with seed data"""
    # Seed organizations
    db_session.add(Organization(
        org_id="org_seed001",
        name="Seed Org",
        tier="pro",
        status="active"
    ))

    # Seed workspaces
    db_session.add(Workspace(
        workspace_id="ws_seed001",
        org_id="org_seed001",
        name="Seed Workspace",
        status="active"
    ))

    db_session.commit()
    yield db_session
```

### 4.4 CI/CD Pipeline Integration

```yaml
# .github/workflows/test.yml

name: Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: |
          pip install uv
          uv pip install -e ".[dev]"

      - name: Run unit tests
        run: pytest -m unit --cov --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: coverage.xml

  integration-tests:
    runs-on: ubuntu-latest
    services:
      redis:
        image: redis:7
        ports:
          - 6379:6379
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: |
          pip install uv
          uv pip install -e ".[dev]"

      - name: Run integration tests
        run: pytest -m integration
        env:
          REDIS_URL: redis://localhost:6379
          DATABASE_URL: postgresql://postgres:test@localhost:5432/test

  e2e-tests:
    runs-on: ubuntu-latest
    needs: [unit-tests, integration-tests]
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Start services
        run: docker compose -f docker-compose.test.yml up -d

      - name: Wait for services
        run: sleep 10

      - name: Run E2E tests
        run: pytest -m e2e

      - name: Stop services
        run: docker compose -f docker-compose.test.yml down
```

---

## 5. Coverage Requirements

### 5.1 Coverage Thresholds

```ini
# pyproject.toml

[tool.coverage.run]
source = ["src/feedback_arrow"]
branch = true
omit = [
    "*/tests/*",
    "*/__main__.py",
]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise NotImplementedError",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.:",
]
fail_under = 80

[tool.coverage.html]
directory = "coverage_html"
```

### 5.2 Critical Path Coverage

```python
# Critical paths that MUST have 100% coverage

CRITICAL_PATHS = [
    "feedback_arrow.auth.api_key",      # API key validation
    "feedback_arrow.auth.rbac",          # Permission checks
    "feedback_arrow.tenancy.context",    # Tenant isolation
    "feedback_arrow.tenancy.quota",      # Quota enforcement
    "feedback_arrow.analysis.pipeline",  # Core analysis logic
    "feedback_arrow.providers.router",   # LLM routing
]

# pytest hook to enforce
def pytest_sessionfinish(session, exitstatus):
    """Enforce critical path coverage"""
    if exitstatus == 0:
        cov = session.config.pluginmanager.get_plugin("_cov")
        if cov:
            for path in CRITICAL_PATHS:
                module_cov = cov.cov.get_data().measured_files()
                # Check coverage for critical paths
                # Fail if < 100%
```

### 5.3 Mutation Testing

```bash
# Install mutmut
pip install mutmut

# Run mutation testing on critical paths
mutmut run --paths-to-mutate=src/feedback_arrow/auth/

# Generate report
mutmut results
mutmut html
```

**Mutation Testing Targets:**
- All security-critical code (auth, RBAC)
- Quota enforcement logic
- Cost calculation formulas
- Data validation functions

---

## 6. Test Patterns

### 6.1 Unit Test Pattern

```python
# tests/unit/test_sentiment.py

import pytest
from feedback_arrow.analysis.sentiment import calculate_sentiment

class TestCalculateSentiment:
    """Unit tests for sentiment calculation"""

    @pytest.mark.unit
    def test_positive_sentiment(self):
        """Positive keywords result in positive sentiment"""
        result = calculate_sentiment("I love this product!", language="en")
        assert result.sentiment == "positive"
        assert result.score > 0.5

    @pytest.mark.unit
    def test_negative_sentiment(self):
        """Negative keywords result in negative sentiment"""
        result = calculate_sentiment("Terrible experience", language="en")
        assert result.sentiment == "negative"
        assert result.score < 0.5

    @pytest.mark.unit
    def test_neutral_sentiment(self):
        """Neutral text results in neutral sentiment"""
        result = calculate_sentiment("The product arrived", language="en")
        assert result.sentiment == "neutral"
        assert 0.4 <= result.score <= 0.6

    @pytest.mark.unit
    @pytest.mark.parametrize("text,expected", [
        ("Excelente!", "positive"),
        ("Terrible!", "negative"),
        ("Normal", "neutral"),
    ])
    def test_spanish_sentiment(self, text, expected):
        """Spanish sentiment detection works"""
        result = calculate_sentiment(text, language="es")
        assert result.sentiment == expected
```

### 6.2 Integration Test Pattern

```python
# tests/integration/test_analysis_pipeline.py

import pytest
from feedback_arrow.analysis import AnalysisPipeline

@pytest.mark.integration
class TestAnalysisPipeline:
    """Integration tests for analysis pipeline"""

    @pytest.fixture
    def pipeline(self, container):
        return container.resolve(AnalysisPipeline)

    async def test_full_analysis_flow(self, pipeline, sample_input, tenant_ctx):
        """Complete analysis flow produces expected output schema"""
        result = await pipeline.analyze(sample_input, tenant_ctx)

        # Verify output schema
        assert "sentiment" in result.column_names
        assert "churn_risk" in result.column_names
        assert len(result) == len(sample_input)

    async def test_caching_works(self, pipeline, sample_input, tenant_ctx, mock_cache):
        """Second analysis uses cache"""
        # First analysis
        await pipeline.analyze(sample_input, tenant_ctx)

        # Second analysis with same input
        await pipeline.analyze(sample_input, tenant_ctx)

        # Verify cache was used
        assert mock_cache.get_stats()["hit_rate"] > 0

    async def test_quota_enforcement(self, pipeline, tenant_ctx):
        """Quota limits are enforced"""
        tenant_ctx.quotas.max_rows_per_analysis = 5
        large_input = DataFactory.create_table(rows=10)

        with pytest.raises(QuotaExceededError):
            await pipeline.analyze(large_input, tenant_ctx)
```

### 6.3 E2E Test Pattern

```python
# tests/e2e/test_api_analyze.py

import pytest
from httpx import AsyncClient

@pytest.mark.e2e
class TestAnalyzeAPI:
    """E2E tests for /api/v1/analyze endpoint"""

    @pytest.fixture
    async def client(self, app):
        async with AsyncClient(app=app, base_url="http://test") as client:
            yield client

    @pytest.fixture
    def api_key(self):
        return "fa_test_abc123def456"

    async def test_analyze_success(self, client, api_key, sample_csv):
        """Successful analysis returns task ID"""
        response = await client.post(
            "/api/v1/analyze",
            headers={"Authorization": f"Bearer {api_key}"},
            files={"file": ("data.csv", sample_csv, "text/csv")}
        )

        assert response.status_code == 202
        data = response.json()
        assert "task_id" in data
        assert data["task_id"].startswith("ana_")

    async def test_analyze_unauthorized(self, client):
        """Missing API key returns 401"""
        response = await client.post("/api/v1/analyze")
        assert response.status_code == 401

    async def test_analyze_rate_limited(self, client, api_key):
        """Exceeding rate limit returns 429"""
        # Make requests until rate limited
        for _ in range(100):
            response = await client.post(
                "/api/v1/analyze",
                headers={"Authorization": f"Bearer {api_key}"}
            )
            if response.status_code == 429:
                break

        assert response.status_code == 429
        assert "Retry-After" in response.headers
```

### 6.4 Golden Dataset Test Pattern

```python
# tests/golden/test_golden_datasets.py

import pytest
from feedback_arrow.validation import compare_results

@pytest.mark.golden
class TestGoldenDatasets:
    """Tests against golden datasets"""

    @pytest.fixture
    def golden_registry(self):
        return GoldenDatasetRegistry()

    @pytest.mark.parametrize("dataset_name", [
        "spanish_nps_basic",
        "spanish_churn_signals",
        "english_sentiment",
    ])
    async def test_golden_dataset(self, pipeline, golden_registry, dataset_name):
        """Analysis matches golden dataset expectations"""
        golden = golden_registry.get(dataset_name)

        result = await pipeline.analyze(
            golden.input,
            TenantFactory.create()
        )

        comparison = compare_results(
            actual=result,
            expected=golden.expected,
            tolerance=golden.tolerance
        )

        assert comparison.passed, f"Golden test failed: {comparison.failures}"

    async def test_regression_detection(self, pipeline, golden_registry):
        """Detect regressions in analysis quality"""
        for golden in golden_registry.load_all():
            result = await pipeline.analyze(
                golden.input,
                TenantFactory.create()
            )

            # Calculate accuracy metrics
            accuracy = calculate_accuracy(result, golden.expected)

            # Must meet minimum threshold
            assert accuracy >= golden.metadata["min_accuracy"], \
                f"Regression in {golden.name}: {accuracy} < {golden.metadata['min_accuracy']}"
```

---

**Cross-References:**
- Mock implementations: `DI_SPEC.md` Section 5
- Golden datasets: `VALIDATION_SUITE.md`
- CI/CD: `OPERATIONS_SPEC.md`
- LLM provider interface: `LLM_PROVIDER_CONTRACT.md`
- Provider routing strategies: `LLM_PROVIDER_CONTRACT.md` Section 3
