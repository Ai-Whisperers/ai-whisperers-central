# Dependency Injection Specification

**Purpose:** Service composition, lifecycle management, and testability
**Status:** Authoritative
**Date:** 2025-12-19

---

## 1. Container Specification

### 1.1 Container Interface

```python
from typing import TypeVar, Type, Optional, Callable
from contextlib import contextmanager

T = TypeVar("T")

class IContainer(Protocol):
    """Dependency injection container interface"""

    def register(
        self,
        interface: Type[T],
        implementation: Type[T],
        lifecycle: Lifecycle = Lifecycle.SINGLETON
    ) -> None:
        """Register implementation for interface"""
        ...

    def register_factory(
        self,
        interface: Type[T],
        factory: Callable[["IContainer"], T],
        lifecycle: Lifecycle = Lifecycle.SINGLETON
    ) -> None:
        """Register factory function for interface"""
        ...

    def register_instance(
        self,
        interface: Type[T],
        instance: T
    ) -> None:
        """Register pre-created instance"""
        ...

    def resolve(self, interface: Type[T]) -> T:
        """Resolve instance for interface"""
        ...

    def try_resolve(self, interface: Type[T]) -> Optional[T]:
        """Try to resolve, return None if not registered"""
        ...

    @contextmanager
    def scope(self, scope_name: str) -> "IContainer":
        """Create a scoped child container"""
        ...
```

### 1.2 Implementation Choice

**Recommended:** `dependency-injector` library

```python
from dependency_injector import containers, providers

class Container(containers.DeclarativeContainer):
    """Main DI container using dependency-injector"""

    # Configuration
    config = providers.Configuration()

    # Singletons
    secret_store = providers.Singleton(
        EnvSecretStore
    )

    # Factory with dependencies
    cache = providers.Singleton(
        create_cache,
        config=config.cache,
        storage=providers.Dependency()
    )
```

**Alternative:** Pure Python implementation for simplicity

```python
class SimpleContainer(IContainer):
    """Minimal DI container without external dependencies"""

    def __init__(self):
        self._registrations: Dict[Type, Registration] = {}
        self._singletons: Dict[Type, Any] = {}
        self._parent: Optional["SimpleContainer"] = None

    def register(
        self,
        interface: Type[T],
        implementation: Type[T],
        lifecycle: Lifecycle = Lifecycle.SINGLETON
    ) -> None:
        self._registrations[interface] = Registration(
            implementation=implementation,
            factory=None,
            lifecycle=lifecycle
        )

    def resolve(self, interface: Type[T]) -> T:
        if interface not in self._registrations:
            if self._parent:
                return self._parent.resolve(interface)
            raise ResolutionError(f"No registration for {interface}")

        reg = self._registrations[interface]

        # Check singleton cache
        if reg.lifecycle == Lifecycle.SINGLETON:
            if interface in self._singletons:
                return self._singletons[interface]

        # Create instance
        if reg.factory:
            instance = reg.factory(self)
        else:
            instance = self._create_instance(reg.implementation)

        # Cache if singleton
        if reg.lifecycle == Lifecycle.SINGLETON:
            self._singletons[interface] = instance

        return instance

    def _create_instance(self, cls: Type[T]) -> T:
        """Create instance with auto-resolved dependencies"""
        hints = get_type_hints(cls.__init__)
        kwargs = {}
        for name, type_hint in hints.items():
            if name == "return":
                continue
            kwargs[name] = self.resolve(type_hint)
        return cls(**kwargs)
```

### 1.3 Container Hierarchy

```
Application Container (root)
    │
    │   Lifecycle: Application lifetime
    │   Contains: Config, Secrets, Observability
    │
    └── Request Container (per HTTP request)
            │
            │   Lifecycle: Single request
            │   Contains: TenantContext, AuditLogger, RequestId
            │
            └── Job Container (per background job)
                    │
                    │   Lifecycle: Single job execution
                    │   Contains: JobContext, Checkpointer
```

```python
class ContainerHierarchy:
    """Manages container hierarchy"""

    def __init__(self, app_container: IContainer):
        self.app = app_container

    @contextmanager
    def request_scope(self, request: Request) -> IContainer:
        """Create request-scoped container"""
        request_container = self.app.create_child()

        # Register request-specific services
        request_container.register_instance(
            Request, request
        )
        request_container.register_instance(
            RequestId, RequestId(str(uuid.uuid4()))
        )

        # Resolve tenant context from request
        tenant_ctx = self._extract_tenant_context(request)
        request_container.register_instance(TenantContext, tenant_ctx)

        # Scoped services
        request_container.register(
            IAuditLogger,
            ScopedAuditLogger,
            Lifecycle.SCOPED
        )

        try:
            yield request_container
        finally:
            request_container.dispose()

    @contextmanager
    def job_scope(self, job_id: str, tenant_ctx: TenantContext) -> IContainer:
        """Create job-scoped container"""
        job_container = self.app.create_child()

        job_container.register_instance(
            JobContext,
            JobContext(job_id=job_id, tenant=tenant_ctx)
        )
        job_container.register_instance(TenantContext, tenant_ctx)

        job_container.register(
            ICheckpointer,
            JobCheckpointer,
            Lifecycle.SCOPED
        )

        try:
            yield job_container
        finally:
            job_container.dispose()
```

### 1.4 Thread Safety

```python
class ThreadSafeContainer(IContainer):
    """Thread-safe container implementation"""

    def __init__(self):
        self._lock = threading.RLock()
        self._registrations: Dict[Type, Registration] = {}
        self._singletons: Dict[Type, Any] = {}

    def resolve(self, interface: Type[T]) -> T:
        reg = self._registrations.get(interface)
        if not reg:
            raise ResolutionError(f"No registration for {interface}")

        if reg.lifecycle == Lifecycle.SINGLETON:
            # Double-checked locking for singletons
            if interface in self._singletons:
                return self._singletons[interface]

            with self._lock:
                if interface in self._singletons:
                    return self._singletons[interface]

                instance = self._create(reg)
                self._singletons[interface] = instance
                return instance

        # Non-singleton: create new instance (no lock needed)
        return self._create(reg)
```

---

## 2. Service Lifecycles

### 2.1 Lifecycle Definitions

```python
class Lifecycle(Enum):
    """Service lifecycle options"""

    SINGLETON = "singleton"
    """One instance per application lifetime.
    Created on first resolve, reused for all subsequent resolves.
    Examples: Config, LLMRouter, GlobalCache
    """

    SCOPED = "scoped"
    """One instance per scope (request, job, etc).
    Created fresh for each scope, disposed when scope ends.
    Examples: TenantContext, AuditLogger, RequestId
    """

    TRANSIENT = "transient"
    """New instance on every resolve.
    No caching, created fresh each time.
    Examples: ComputeNode, AnalysisTask
    """
```

### 2.2 Service Classification

| Service | Lifecycle | Rationale |
|---------|-----------|-----------|
| **Configuration** |
| `FeedbackArrowConfig` | Singleton | Loaded once at startup |
| `FeatureFlagService` | Singleton | Cached, refreshed periodically |
| **Infrastructure** |
| `ISecretStore` | Singleton | Connection pooled |
| `ICache` | Singleton | Connection pooled |
| `IPersistence` | Singleton | Connection pooled |
| `IStorage` | Singleton | Stateless, connection pooled |
| `IObservability` | Singleton | Global metrics/traces |
| **LLM Providers** |
| `ILLMProvider` (each) | Singleton | HTTP client pooled |
| `LLMRouter` | Singleton | Wraps singleton providers |
| **Per-Request** |
| `TenantContext` | Scoped | Different per request |
| `IAuditLogger` | Scoped | Includes request context |
| `RequestId` | Scoped | Unique per request |
| **Per-Job** |
| `JobContext` | Scoped | Different per job |
| `ICheckpointer` | Scoped | Job-specific state |
| **Processing** |
| `IComputeNode` | Transient | Stateless transformer |
| `IComputeGraph` | Transient | Built per analysis |
| `AnalysisTask` | Transient | One per analysis |

### 2.3 Lazy Initialization

```python
class LazyProvider:
    """Lazy initialization wrapper"""

    def __init__(self, factory: Callable[[], T]):
        self._factory = factory
        self._instance: Optional[T] = None
        self._lock = threading.Lock()

    def get(self) -> T:
        if self._instance is None:
            with self._lock:
                if self._instance is None:
                    self._instance = self._factory()
        return self._instance

# Usage in container
class Container:
    def __init__(self):
        # Expensive services initialized lazily
        self._llm_router = LazyProvider(self._create_llm_router)

    def _create_llm_router(self) -> LLMRouter:
        # Only called when first accessed
        config = self.resolve(FeedbackArrowConfig)
        providers = []
        if config.providers.ollama.enabled:
            providers.append(OllamaAdapter(config.providers.ollama))
        if config.providers.openai.enabled:
            providers.append(OpenAIAdapter(config.providers.openai))
        # ...
        return LLMRouter(providers, config.providers.routing_strategy)
```

### 2.4 Disposal Pattern

```python
class IDisposable(Protocol):
    """Interface for services requiring cleanup"""

    async def dispose(self) -> None:
        """Release resources"""
        ...

class DisposableContainer(IContainer):
    """Container that tracks and disposes services"""

    def __init__(self):
        self._disposables: List[IDisposable] = []

    def register(self, interface: Type[T], implementation: Type[T], ...):
        # Track if disposable
        if issubclass(implementation, IDisposable):
            self._track_disposable = True
        # ...

    def resolve(self, interface: Type[T]) -> T:
        instance = super().resolve(interface)
        if isinstance(instance, IDisposable):
            self._disposables.append(instance)
        return instance

    async def dispose(self) -> None:
        """Dispose all tracked services in reverse order"""
        for disposable in reversed(self._disposables):
            try:
                await disposable.dispose()
            except Exception as e:
                logger.error(f"Error disposing {type(disposable)}: {e}")
        self._disposables.clear()

# Example disposable service
class RedisCache(ICache, IDisposable):
    def __init__(self, redis_url: str):
        self._pool = redis.ConnectionPool.from_url(redis_url)
        self._client = redis.Redis(connection_pool=self._pool)

    async def dispose(self) -> None:
        await self._client.close()
        await self._pool.disconnect()
```

---

## 3. Composition Patterns

### 3.1 Production Composition

```python
def create_production_container(config: FeedbackArrowConfig) -> IContainer:
    """Create fully-configured production container"""

    container = Container()

    # Configuration (already loaded)
    container.register_instance(FeedbackArrowConfig, config)

    # Level 0: Foundation (no dependencies)
    container.register(ISecretStore, create_secret_store(config))
    container.register(IObservability, create_observability(config))

    # Level 1: Infrastructure
    container.register(
        IStorage,
        lambda c: S3Storage(config.export.output_path)
        if config.env == Environment.PRODUCTION
        else LocalStorage(config.export.output_path)
    )

    container.register(
        ICache,
        lambda c: RedisCache(config.cache.redis_url)
        if config.cache.backend == "redis"
        else MemoryCache(config.cache.memory_max_size_mb)
    )

    container.register(
        IPersistence,
        lambda c: PostgresPersistence(config.database.url)
        if config.database.url.startswith("postgresql")
        else DuckDBPersistence(config.database.url)
    )

    # Level 2: LLM Providers
    container.register(
        LLMRouter,
        lambda c: create_llm_router(config, c.resolve(ISecretStore))
    )

    # Level 3: Services
    container.register(
        QuotaEnforcer,
        lambda c: QuotaEnforcer(c.resolve(IPersistence))
    )

    container.register(
        AnalysisPipeline,
        lambda c: AnalysisPipeline(
            llm_router=c.resolve(LLMRouter),
            cache=c.resolve(ICache),
            observer=c.resolve(IObservability)
        )
    )

    return container

def create_llm_router(config: FeedbackArrowConfig, secrets: ISecretStore) -> LLMRouter:
    """Create LLM router with all enabled providers"""
    providers = []

    if config.providers.ollama.enabled:
        providers.append(OllamaAdapter(config.providers.ollama))

    if config.providers.vllm.enabled:
        providers.append(VLLMAdapter(config.providers.vllm))

    if config.providers.openai.enabled:
        api_key = secrets.get_secret("OPENAI_API_KEY")
        providers.append(OpenAIAdapter(config.providers.openai, api_key))

    if config.providers.anthropic.enabled:
        api_key = secrets.get_secret("ANTHROPIC_API_KEY")
        providers.append(AnthropicAdapter(config.providers.anthropic, api_key))

    return LLMRouter(
        providers=providers,
        strategy=config.providers.routing_strategy,
        fallback_order=config.providers.failover_order
    )
```

### 3.2 Test Composition

```python
def create_test_container(
    config_overrides: Optional[Dict] = None,
    mock_llm: bool = True,
    mock_cache: bool = True,
    mock_persistence: bool = True
) -> IContainer:
    """Create container for testing with mocks"""

    # Start with test config
    config = create_test_config(config_overrides)
    container = Container()
    container.register_instance(FeedbackArrowConfig, config)

    # Foundation - always real
    container.register(ISecretStore, DictSecretStore, Lifecycle.SINGLETON)
    container.register(IObservability, NullObserver, Lifecycle.SINGLETON)

    # Infrastructure - mock or real based on flags
    if mock_cache:
        container.register(ICache, MemoryCache, Lifecycle.SINGLETON)
    else:
        container.register(ICache, create_cache_from_config(config))

    if mock_persistence:
        container.register(IPersistence, MemoryPersistence, Lifecycle.SINGLETON)
    else:
        container.register(IPersistence, create_persistence_from_config(config))

    container.register(IStorage, MemoryStorage, Lifecycle.SINGLETON)

    # LLM - mock or real
    if mock_llm:
        container.register(LLMRouter, MockLLMRouter, Lifecycle.SINGLETON)
    else:
        container.register(
            LLMRouter,
            lambda c: create_llm_router(config, c.resolve(ISecretStore))
        )

    # Services
    container.register(QuotaEnforcer, QuotaEnforcer, Lifecycle.SINGLETON)
    container.register(AnalysisPipeline, AnalysisPipeline, Lifecycle.SINGLETON)

    return container

def create_test_config(overrides: Optional[Dict] = None) -> FeedbackArrowConfig:
    """Create test configuration"""
    base = {
        "env": "testing",
        "database": {"url": "sqlite:///:memory:"},
        "cache": {"backend": "memory"},
        "providers": {
            "default": "mock",
            "ollama": {"enabled": False},
            "openai": {"enabled": False},
        },
        "analysis": {
            "batch_size": 5,
            "enable_checkpointing": False
        }
    }
    if overrides:
        base = deep_merge(base, overrides)
    return FeedbackArrowConfig(**base)
```

### 3.3 CLI Composition

```python
def create_cli_container(args: argparse.Namespace) -> IContainer:
    """Create minimal container for CLI usage"""

    # Load config with CLI overrides
    config = load_config_with_overrides(args)
    container = Container()
    container.register_instance(FeedbackArrowConfig, config)

    # Minimal infrastructure
    container.register(ISecretStore, EnvSecretStore, Lifecycle.SINGLETON)
    container.register(IObservability, ConsoleObserver, Lifecycle.SINGLETON)
    container.register(IStorage, LocalStorage, Lifecycle.SINGLETON)
    container.register(ICache, MemoryCache, Lifecycle.SINGLETON)

    # CLI doesn't need persistence (stateless)
    container.register(IPersistence, NullPersistence, Lifecycle.SINGLETON)

    # LLM providers (only what's needed)
    container.register(
        LLMRouter,
        lambda c: create_llm_router(config, c.resolve(ISecretStore))
    )

    # Analysis pipeline
    container.register(AnalysisPipeline, AnalysisPipeline, Lifecycle.SINGLETON)

    return container

def load_config_with_overrides(args: argparse.Namespace) -> FeedbackArrowConfig:
    """Load config and apply CLI argument overrides"""
    config = ConfigLoader().load()

    # Apply CLI overrides
    if hasattr(args, "provider") and args.provider:
        config.providers.default = args.provider
    if hasattr(args, "batch_size") and args.batch_size:
        config.analysis.batch_size = args.batch_size
    if hasattr(args, "language") and args.language:
        config.analysis.default_language = args.language

    return config
```

### 3.4 Worker Composition

```python
def create_worker_container(config: FeedbackArrowConfig) -> IContainer:
    """Create container for background job workers"""

    container = Container()
    container.register_instance(FeedbackArrowConfig, config)

    # Full infrastructure (workers need everything)
    container.register(ISecretStore, create_secret_store(config))
    container.register(IObservability, create_observability(config))
    container.register(IStorage, create_storage(config))
    container.register(ICache, create_cache(config))
    container.register(IPersistence, create_persistence(config))

    # LLM providers
    container.register(
        LLMRouter,
        lambda c: create_llm_router(config, c.resolve(ISecretStore))
    )

    # Worker-specific services
    container.register(
        JobQueue,
        lambda c: RedisJobQueue(config.cache.redis_url)
    )

    container.register(
        WorkerPool,
        lambda c: WorkerPool(
            queue=c.resolve(JobQueue),
            container=container,  # Pass for job scope creation
            max_workers=config.server.workers
        )
    )

    return container
```

---

## 4. Interface Bindings

### 4.1 Binding Map

```python
# Default bindings per environment
BINDINGS = {
    Environment.DEVELOPMENT: {
        ISecretStore: EnvSecretStore,
        IStorage: LocalStorage,
        ICache: MemoryCache,
        IPersistence: DuckDBPersistence,
        IObservability: ConsoleObserver,
    },
    Environment.TESTING: {
        ISecretStore: DictSecretStore,
        IStorage: MemoryStorage,
        ICache: MemoryCache,
        IPersistence: MemoryPersistence,
        IObservability: NullObserver,
    },
    Environment.STAGING: {
        ISecretStore: VaultSecretStore,
        IStorage: S3Storage,
        ICache: RedisCache,
        IPersistence: PostgresPersistence,
        IObservability: OTLPObserver,
    },
    Environment.PRODUCTION: {
        ISecretStore: VaultSecretStore,
        IStorage: S3Storage,
        ICache: RedisCache,
        IPersistence: PostgresPersistence,
        IObservability: OTLPObserver,
    },
}

def get_default_binding(interface: Type, env: Environment) -> Type:
    """Get default implementation for interface in environment"""
    return BINDINGS[env].get(interface)
```

### 4.2 Conditional Bindings

```python
def register_conditional_bindings(container: IContainer, config: FeedbackArrowConfig):
    """Register bindings based on configuration"""

    # Cache: Redis if URL provided, else memory
    if config.cache.redis_url:
        container.register(
            ICache,
            lambda c: RedisCache(config.cache.redis_url),
            Lifecycle.SINGLETON
        )
    else:
        container.register(
            ICache,
            lambda c: MemoryCache(config.cache.memory_max_size_mb),
            Lifecycle.SINGLETON
        )

    # Storage: S3 if bucket configured, else local
    if config.export.output_path.startswith("s3://"):
        container.register(
            IStorage,
            lambda c: S3Storage(config.export.output_path),
            Lifecycle.SINGLETON
        )
    else:
        container.register(
            IStorage,
            lambda c: LocalStorage(config.export.output_path),
            Lifecycle.SINGLETON
        )

    # Persistence: PostgreSQL or DuckDB based on URL scheme
    if config.database.url.startswith("postgresql"):
        container.register(
            IPersistence,
            lambda c: PostgresPersistence(config.database.url),
            Lifecycle.SINGLETON
        )
    else:
        container.register(
            IPersistence,
            lambda c: DuckDBPersistence(config.database.url),
            Lifecycle.SINGLETON
        )
```

### 4.3 Factory Patterns

```python
class ServiceFactory:
    """Factory for creating services with dynamic resolution"""

    def __init__(self, container: IContainer):
        self._container = container

    def create_analysis_task(
        self,
        tenant_ctx: TenantContext,
        input_data: pa.Table
    ) -> AnalysisTask:
        """Create analysis task with resolved dependencies"""
        return AnalysisTask(
            tenant_ctx=tenant_ctx,
            input_data=input_data,
            llm_router=self._container.resolve(LLMRouter),
            cache=TenantAwareCache(
                self._container.resolve(ICache),
                tenant_ctx
            ),
            checkpointer=self._container.resolve(ICheckpointer),
            observer=self._container.resolve(IObservability)
        )

    def create_compute_graph(
        self,
        tenant_ctx: TenantContext
    ) -> IComputeGraph:
        """Create compute graph for analysis"""
        return AnalysisPipelineGraph(
            llm_router=self._container.resolve(LLMRouter),
            cache=TenantAwareCache(
                self._container.resolve(ICache),
                tenant_ctx
            ),
            language_pack=self._get_language_pack(tenant_ctx),
            observer=self._container.resolve(IObservability)
        )

    def _get_language_pack(self, ctx: TenantContext) -> ILanguagePack:
        """Get language pack for tenant"""
        config = self._container.resolve(FeedbackArrowConfig)
        # Could be tenant override or default
        language = ctx.settings.get("language", config.analysis.default_language)
        return load_language_pack(language)
```

---

## 5. Testing Support

### 5.1 Mock Container

```python
class MockContainer(IContainer):
    """Container for unit tests with auto-mocking"""

    def __init__(self):
        self._mocks: Dict[Type, Any] = {}
        self._stubs: Dict[Type, Any] = {}

    def mock(self, interface: Type[T]) -> Mock:
        """Get or create mock for interface"""
        if interface not in self._mocks:
            self._mocks[interface] = Mock(spec=interface)
        return self._mocks[interface]

    def stub(self, interface: Type[T], instance: T) -> None:
        """Provide stub implementation"""
        self._stubs[interface] = instance

    def resolve(self, interface: Type[T]) -> T:
        """Resolve: stub > mock > error"""
        if interface in self._stubs:
            return self._stubs[interface]
        if interface in self._mocks:
            return self._mocks[interface]
        raise ResolutionError(f"No mock or stub for {interface}")

# Usage in tests
def test_analysis_with_mock_llm():
    container = MockContainer()

    # Stub deterministic responses
    mock_llm = MockLLMProvider(responses={
        "positive": AnalysisResult(sentiment="positive", score=0.9),
        "negative": AnalysisResult(sentiment="negative", score=0.2),
    })
    container.stub(LLMRouter, mock_llm)

    # Mock what we don't care about
    container.mock(ICache)
    container.mock(IObservability)

    # Test
    pipeline = AnalysisPipeline(
        llm_router=container.resolve(LLMRouter),
        cache=container.resolve(ICache),
        observer=container.resolve(IObservability)
    )

    result = pipeline.analyze("I love this product!")
    assert result.sentiment == "positive"
```

### 5.2 Override Patterns

```python
@pytest.fixture
def production_container_with_overrides():
    """Create production container with test overrides"""
    container = create_production_container(create_test_config())

    # Override specific services for testing
    container.override(ICache, MemoryCache())
    container.override(IPersistence, MemoryPersistence())

    yield container

    # Restore originals
    container.restore_all()

class OverridableContainer(IContainer):
    """Container that supports temporary overrides"""

    def __init__(self, base: IContainer):
        self._base = base
        self._overrides: Dict[Type, Any] = {}
        self._original: Dict[Type, Any] = {}

    def override(self, interface: Type[T], instance: T) -> None:
        """Temporarily override a registration"""
        if interface not in self._original:
            self._original[interface] = self._base.try_resolve(interface)
        self._overrides[interface] = instance

    def restore(self, interface: Type[T]) -> None:
        """Restore original registration"""
        if interface in self._overrides:
            del self._overrides[interface]

    def restore_all(self) -> None:
        """Restore all overrides"""
        self._overrides.clear()

    def resolve(self, interface: Type[T]) -> T:
        if interface in self._overrides:
            return self._overrides[interface]
        return self._base.resolve(interface)
```

### 5.3 Fixture Factories

```python
class TestFixtures:
    """Factory for creating test fixtures"""

    def __init__(self, container: IContainer):
        self._container = container

    def create_tenant_context(
        self,
        workspace_id: str = "ws_test123",
        tier: Tier = Tier.PRO,
        **kwargs
    ) -> TenantContext:
        """Create test tenant context"""
        return TenantContext(
            org_id=kwargs.get("org_id", "org_test123"),
            workspace_id=workspace_id,
            project_id=kwargs.get("project_id"),
            user_id=kwargs.get("user_id", "usr_test123"),
            api_key_id=kwargs.get("api_key_id"),
            tier=tier,
            quotas=self._get_tier_quotas(tier)
        )

    def create_analysis_input(
        self,
        rows: int = 10,
        language: str = "es"
    ) -> pa.Table:
        """Create test analysis input"""
        return pa.table({
            "id": list(range(rows)),
            "user_score": [random.uniform(1, 10) for _ in range(rows)],
            "customer_comment": [
                self._generate_comment(language) for _ in range(rows)
            ]
        })

    def create_job_context(
        self,
        tenant_ctx: Optional[TenantContext] = None
    ) -> JobContext:
        """Create test job context"""
        if tenant_ctx is None:
            tenant_ctx = self.create_tenant_context()
        return JobContext(
            job_id=f"job_{ulid.new().str.lower()}",
            tenant=tenant_ctx
        )

# Usage
@pytest.fixture
def fixtures(test_container):
    return TestFixtures(test_container)

def test_analysis(fixtures):
    ctx = fixtures.create_tenant_context(tier=Tier.ENTERPRISE)
    input_data = fixtures.create_analysis_input(rows=100)
    # ...
```

---

## 6. FastAPI Integration

### 6.1 Dependency Injection in FastAPI

```python
from fastapi import Depends, Request

# Global container reference
_app_container: Optional[IContainer] = None

def get_container() -> IContainer:
    """Get application container"""
    if _app_container is None:
        raise RuntimeError("Container not initialized")
    return _app_container

def get_tenant_context(request: Request) -> TenantContext:
    """Extract tenant context from request (set by middleware)"""
    return request.state.tenant_ctx

def get_analysis_pipeline(
    container: IContainer = Depends(get_container)
) -> AnalysisPipeline:
    """Resolve analysis pipeline"""
    return container.resolve(AnalysisPipeline)

def get_llm_router(
    container: IContainer = Depends(get_container)
) -> LLMRouter:
    """Resolve LLM router"""
    return container.resolve(LLMRouter)

# Usage in endpoints
@router.post("/analyze")
async def analyze(
    request: AnalyzeRequest,
    tenant_ctx: TenantContext = Depends(get_tenant_context),
    pipeline: AnalysisPipeline = Depends(get_analysis_pipeline),
    quota_enforcer: QuotaEnforcer = Depends(get_quota_enforcer)
):
    # Check quota
    await quota_enforcer.check_can_analyze(tenant_ctx, request.row_count)

    # Run analysis
    result = await pipeline.analyze(
        input_data=request.data,
        tenant_ctx=tenant_ctx
    )

    return AnalyzeResponse(task_id=result.task_id)
```

### 6.2 Application Lifecycle

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle manager"""
    global _app_container

    # Startup
    config = ConfigLoader().load()
    _app_container = create_production_container(config)

    # Initialize services
    await _app_container.resolve(IPersistence).initialize()
    await _app_container.resolve(ICache).initialize()

    logger.info("Application started", extra={"env": config.env.value})

    yield

    # Shutdown
    logger.info("Shutting down...")
    await _app_container.dispose()
    _app_container = None

app = FastAPI(lifespan=lifespan)
```

---

**Cross-References:**
- Service interfaces: `COMPUTE_GRAPH_SPEC.md`, `STATE_STORE_SPEC.md`
- Configuration: `CONFIG_SPEC.md`
- Testing: `TESTING_SPEC.md`
- Tenant context: `MULTI_TENANCY_SPEC.md`
