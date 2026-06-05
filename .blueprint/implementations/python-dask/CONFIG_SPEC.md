# Configuration Specification

**Purpose:** Configuration hierarchy, validation, feature flags, and per-tenant overrides
**Status:** Authoritative
**Date:** 2025-12-19

---

## 1. Configuration Hierarchy

### 1.1 Priority Order

Configuration values are resolved in the following priority order (highest to lowest):

```
1. CLI Arguments        --provider=openai
2. Environment Variables  FEEDBACK_ARROW_PROVIDER=openai
3. Workspace Config     (stored in database per workspace)
4. Config File          ~/.feedback-arrow/config.toml
5. System Config        /etc/feedback-arrow/config.toml
6. Defaults             Built into application
```

**Resolution Rule:** First non-null value wins.

### 1.2 Environment Detection

```python
class Environment(Enum):
    DEVELOPMENT = "development"
    TESTING = "testing"
    STAGING = "staging"
    PRODUCTION = "production"

def detect_environment() -> Environment:
    """Detect current environment from ENV variables"""
    env_var = os.environ.get("FEEDBACK_ARROW_ENV", "development").lower()

    mapping = {
        "dev": Environment.DEVELOPMENT,
        "development": Environment.DEVELOPMENT,
        "test": Environment.TESTING,
        "testing": Environment.TESTING,
        "staging": Environment.STAGING,
        "stg": Environment.STAGING,
        "prod": Environment.PRODUCTION,
        "production": Environment.PRODUCTION,
    }

    return mapping.get(env_var, Environment.DEVELOPMENT)
```

### 1.3 Config File Locations

**Search Order:**
```
1. $FEEDBACK_ARROW_CONFIG     # Explicit path via env var
2. ./feedback-arrow.toml      # Current directory
3. ~/.feedback-arrow/config.toml  # User home
4. /etc/feedback-arrow/config.toml  # System-wide
```

**Environment-Specific Files:**
```
~/.feedback-arrow/
├── config.toml              # Base config
├── config.development.toml  # Dev overrides (merged)
├── config.staging.toml      # Staging overrides
└── config.production.toml   # Prod overrides
```

### 1.4 Environment Variable Naming

**Convention:** `FEEDBACK_ARROW_{SECTION}_{KEY}`

```bash
# General
FEEDBACK_ARROW_ENV=production
FEEDBACK_ARROW_LOG_LEVEL=info

# Providers
FEEDBACK_ARROW_PROVIDER_DEFAULT=ollama
FEEDBACK_ARROW_PROVIDER_OLLAMA_HOST=http://localhost:11434
FEEDBACK_ARROW_PROVIDER_OPENAI_API_KEY=sk-xxx

# Database
FEEDBACK_ARROW_DATABASE_URL=postgresql://...
FEEDBACK_ARROW_DATABASE_POOL_SIZE=10

# Cache
FEEDBACK_ARROW_CACHE_REDIS_URL=redis://localhost:6379
FEEDBACK_ARROW_CACHE_TTL_SECONDS=3600
```

**Nested Config Mapping:**
```python
# Environment variable
FEEDBACK_ARROW_PROVIDER_OPENAI_API_KEY=sk-xxx

# Maps to config path
config.provider.openai.api_key = "sk-xxx"
```

---

## 2. Configuration Schema

### 2.1 Root Configuration

```python
from pydantic import BaseModel, Field, field_validator
from typing import Optional, Dict, List, Literal

class FeedbackArrowConfig(BaseModel):
    """Root configuration schema"""

    # Environment
    env: Environment = Environment.DEVELOPMENT
    debug: bool = False
    log_level: Literal["debug", "info", "warning", "error"] = "info"

    # Subsections
    server: ServerConfig = Field(default_factory=ServerConfig)
    database: DatabaseConfig = Field(default_factory=DatabaseConfig)
    cache: CacheConfig = Field(default_factory=CacheConfig)
    providers: ProvidersConfig = Field(default_factory=ProvidersConfig)
    analysis: AnalysisConfig = Field(default_factory=AnalysisConfig)
    export: ExportConfig = Field(default_factory=ExportConfig)
    observability: ObservabilityConfig = Field(default_factory=ObservabilityConfig)
    features: FeatureFlagsConfig = Field(default_factory=FeatureFlagsConfig)

    model_config = {"extra": "forbid"}  # Reject unknown keys
```

### 2.2 Server Configuration

```python
class ServerConfig(BaseModel):
    """API server configuration"""

    host: str = "0.0.0.0"
    port: int = Field(default=8000, ge=1, le=65535)
    workers: int = Field(default=4, ge=1, le=64)
    cors_origins: List[str] = ["*"]
    request_timeout_seconds: int = Field(default=300, ge=1)
    max_request_size_mb: int = Field(default=100, ge=1, le=1000)

    # TLS (production only)
    tls_cert_path: Optional[str] = None
    tls_key_path: Optional[str] = None

    @field_validator("cors_origins")
    @classmethod
    def validate_cors(cls, v):
        if "*" in v and len(v) > 1:
            raise ValueError("Cannot mix '*' with specific origins")
        return v
```

### 2.3 Database Configuration

```python
class DatabaseConfig(BaseModel):
    """Database connection configuration"""

    # Connection
    url: str = "sqlite:///./feedback_arrow.db"
    pool_size: int = Field(default=5, ge=1, le=100)
    pool_timeout_seconds: int = Field(default=30, ge=1)
    echo_sql: bool = False  # Log SQL queries

    # DuckDB-specific
    duckdb_memory_limit: str = "4GB"
    duckdb_threads: int = Field(default=4, ge=1)

    @field_validator("url")
    @classmethod
    def validate_url(cls, v):
        valid_schemes = ["sqlite", "postgresql", "duckdb"]
        scheme = v.split(":")[0]
        if scheme not in valid_schemes:
            raise ValueError(f"Database scheme must be one of {valid_schemes}")
        return v
```

### 2.4 Cache Configuration

```python
class CacheConfig(BaseModel):
    """Caching layer configuration"""

    # Backend selection
    backend: Literal["memory", "redis", "disk"] = "memory"

    # Memory cache
    memory_max_size_mb: int = Field(default=256, ge=16)
    memory_ttl_seconds: int = Field(default=3600, ge=60)

    # Redis cache
    redis_url: Optional[str] = None
    redis_ttl_seconds: int = Field(default=86400, ge=60)
    redis_key_prefix: str = "fa:"

    # Disk cache (cold tier)
    disk_path: str = "/tmp/feedback-arrow-cache"
    disk_max_size_gb: int = Field(default=10, ge=1)

    # Two-tier config
    enable_two_tier: bool = True
    hot_to_cold_threshold_seconds: int = Field(default=3600, ge=60)

    @field_validator("redis_url")
    @classmethod
    def validate_redis_url(cls, v, info):
        if info.data.get("backend") == "redis" and not v:
            raise ValueError("redis_url required when backend is 'redis'")
        return v
```

### 2.5 Providers Configuration

```python
class ProviderConfig(BaseModel):
    """Individual LLM provider configuration"""
    enabled: bool = False
    priority: int = Field(default=10, ge=1, le=100)
    api_key: Optional[str] = None  # Secret reference
    endpoint: Optional[str] = None
    model: str
    max_tokens: int = Field(default=4096, ge=1)
    temperature: float = Field(default=0.0, ge=0.0, le=2.0)
    timeout_seconds: int = Field(default=60, ge=1)
    max_retries: int = Field(default=3, ge=0)

class OllamaConfig(ProviderConfig):
    """Ollama-specific configuration"""
    enabled: bool = True
    priority: int = 1  # Local first
    endpoint: str = "http://localhost:11434"
    model: str = "llama3.2"
    num_ctx: int = Field(default=8192, ge=1024)

class OpenAIConfig(ProviderConfig):
    """OpenAI-specific configuration"""
    enabled: bool = False
    priority: int = 10
    endpoint: str = "https://api.openai.com/v1"
    model: str = "gpt-4o-mini"
    api_key: Optional[str] = "${OPENAI_API_KEY}"  # Secret reference

class AnthropicConfig(ProviderConfig):
    """Anthropic-specific configuration"""
    enabled: bool = False
    priority: int = 11
    endpoint: str = "https://api.anthropic.com"
    model: str = "claude-3-haiku-20240307"
    api_key: Optional[str] = "${ANTHROPIC_API_KEY}"

class VLLMConfig(ProviderConfig):
    """vLLM-specific configuration"""
    enabled: bool = False
    priority: int = 2  # Local, after Ollama
    endpoint: str = "http://localhost:8000/v1"
    model: str = "meta-llama/Llama-3.2-8B-Instruct"

class ProvidersConfig(BaseModel):
    """All LLM providers configuration"""

    # Default provider selection
    default: str = "ollama"
    routing_strategy: Literal["local_first", "cost", "latency", "quality", "failover"] = "local_first"

    # Individual providers
    ollama: OllamaConfig = Field(default_factory=OllamaConfig)
    openai: OpenAIConfig = Field(default_factory=OpenAIConfig)
    anthropic: AnthropicConfig = Field(default_factory=AnthropicConfig)
    vllm: VLLMConfig = Field(default_factory=VLLMConfig)

    # Routing options
    local_providers: List[str] = ["ollama", "vllm"]
    cloud_providers: List[str] = ["openai", "anthropic"]
    failover_order: List[str] = ["ollama", "vllm", "openai", "anthropic"]
```

### 2.6 Analysis Configuration

```python
class AnalysisConfig(BaseModel):
    """Analysis pipeline configuration"""

    # Batch processing
    batch_size: int = Field(default=50, ge=1, le=1000)
    max_concurrent_batches: int = Field(default=4, ge=1)

    # Timeouts
    analysis_timeout_seconds: int = Field(default=1800, ge=60)  # 30 min
    llm_timeout_seconds: int = Field(default=60, ge=5)

    # Retry behavior
    max_retries: int = Field(default=3, ge=0)
    retry_backoff_base: float = Field(default=2.0, ge=1.0)
    retry_backoff_max_seconds: int = Field(default=60, ge=1)

    # Default language
    default_language: str = "es"

    # Checkpointing
    enable_checkpointing: bool = True
    checkpoint_interval_rows: int = Field(default=100, ge=10)
```

### 2.7 Export Configuration

```python
class ExportConfig(BaseModel):
    """Export system configuration"""

    # Default format
    default_format: Literal["parquet", "csv", "json"] = "parquet"

    # Parquet options
    parquet_compression: Literal["snappy", "gzip", "zstd", "none"] = "snappy"
    parquet_row_group_size: int = Field(default=100000, ge=1000)

    # CSV options
    csv_delimiter: str = ","
    csv_encoding: str = "utf-8-sig"  # BOM for Excel compatibility

    # Storage
    output_path: str = "./exports"
    presigned_url_expiry_seconds: int = Field(default=3600, ge=60)
```

### 2.8 Observability Configuration

```python
class ObservabilityConfig(BaseModel):
    """Logging, metrics, and tracing configuration"""

    # Logging
    log_format: Literal["json", "text"] = "json"
    log_level: Literal["debug", "info", "warning", "error"] = "info"

    # Metrics (Prometheus)
    metrics_enabled: bool = True
    metrics_port: int = Field(default=9090, ge=1, le=65535)
    metrics_path: str = "/metrics"

    # Tracing (OpenTelemetry)
    tracing_enabled: bool = False
    otlp_endpoint: Optional[str] = None
    otlp_headers: Dict[str, str] = {}
    trace_sample_rate: float = Field(default=0.1, ge=0.0, le=1.0)

    # Health check
    health_check_path: str = "/health"
```

---

## 3. Per-Tenant Configuration

### 3.1 Override Mechanism

```python
@dataclass
class TenantConfigOverride:
    """Per-tenant configuration overrides"""
    workspace_id: str
    overrides: Dict[str, Any]  # Dot-notation paths
    created_at: datetime
    updated_at: datetime

# Example overrides
override = TenantConfigOverride(
    workspace_id="ws_abc123",
    overrides={
        "analysis.default_language": "en",
        "providers.default": "openai",
        "analysis.batch_size": 100,
    }
)
```

### 3.2 Inheritable vs Tenant-Specific

| Config Path | Inheritable | Tenant Override | Description |
|-------------|-------------|-----------------|-------------|
| `server.*` | No | No | Server-level only |
| `database.*` | No | No | Server-level only |
| `providers.*.api_key` | No | Yes | Tenant can use own keys |
| `providers.default` | Yes | Yes | Default provider choice |
| `analysis.default_language` | Yes | Yes | Language preference |
| `analysis.batch_size` | Yes | Yes | Processing batch size |
| `export.default_format` | Yes | Yes | Export format |
| `features.*` | Yes | Yes | Feature flags |

### 3.3 Config Merge Strategy

```python
class ConfigResolver:
    """Resolve configuration with tenant overrides"""

    def resolve(
        self,
        base_config: FeedbackArrowConfig,
        tenant_overrides: Optional[TenantConfigOverride]
    ) -> FeedbackArrowConfig:
        """Merge base config with tenant overrides"""

        if not tenant_overrides:
            return base_config

        # Deep copy base config
        config_dict = base_config.model_dump()

        # Apply overrides
        for path, value in tenant_overrides.overrides.items():
            self._set_nested(config_dict, path, value)

        # Validate merged config
        return FeedbackArrowConfig(**config_dict)

    def _set_nested(self, d: dict, path: str, value: Any) -> None:
        """Set value at dot-notation path"""
        keys = path.split(".")
        for key in keys[:-1]:
            d = d.setdefault(key, {})
        d[keys[-1]] = value
```

---

## 4. Feature Flags

### 4.1 Flag Definition Schema

```python
class FeatureFlag(BaseModel):
    """Feature flag definition"""
    name: str
    description: str
    default_value: bool = False
    rollout_percentage: float = Field(default=0.0, ge=0.0, le=100.0)
    enabled_for_tiers: List[str] = []  # ["pro", "enterprise"]
    enabled_for_workspaces: List[str] = []  # Explicit whitelist
    disabled_for_workspaces: List[str] = []  # Explicit blacklist
    created_at: datetime
    updated_at: datetime

class FeatureFlagsConfig(BaseModel):
    """Feature flags configuration"""

    # Individual flags
    streaming_mode: bool = False
    advanced_analytics: bool = False
    custom_models: bool = False
    api_v2: bool = False
    enhanced_explainability: bool = False

    # Dynamic flags (loaded from database)
    dynamic_flags: Dict[str, FeatureFlag] = {}
```

### 4.2 Flag Evaluation Order

```python
class FeatureFlagEvaluator:
    """Evaluate feature flags with context"""

    def is_enabled(
        self,
        flag_name: str,
        context: TenantContext
    ) -> bool:
        """Evaluate flag for given context"""

        flag = self.get_flag(flag_name)
        if not flag:
            return False

        # 1. Check explicit blacklist
        if context.workspace_id in flag.disabled_for_workspaces:
            return False

        # 2. Check explicit whitelist
        if context.workspace_id in flag.enabled_for_workspaces:
            return True

        # 3. Check tier eligibility
        if flag.enabled_for_tiers:
            if context.tier.value not in flag.enabled_for_tiers:
                return False

        # 4. Check rollout percentage
        if flag.rollout_percentage < 100.0:
            # Consistent hashing for stable rollout
            hash_input = f"{flag.name}:{context.workspace_id}"
            hash_value = int(hashlib.md5(hash_input.encode()).hexdigest()[:8], 16)
            bucket = (hash_value % 10000) / 100.0  # 0-100%
            if bucket >= flag.rollout_percentage:
                return False

        # 5. Default value
        return flag.default_value
```

### 4.3 Gradual Rollout

```python
class RolloutManager:
    """Manage gradual feature rollouts"""

    async def start_rollout(
        self,
        flag_name: str,
        target_percentage: float,
        duration_hours: int
    ) -> RolloutPlan:
        """Start gradual rollout"""

        flag = await self.get_flag(flag_name)
        current = flag.rollout_percentage
        steps = duration_hours  # 1% per hour typical

        plan = RolloutPlan(
            flag_name=flag_name,
            start_percentage=current,
            target_percentage=target_percentage,
            step_size=(target_percentage - current) / steps,
            interval_minutes=60,
            started_at=datetime.utcnow()
        )

        await self.schedule_rollout_steps(plan)
        return plan

    async def rollback(self, flag_name: str) -> None:
        """Emergency rollback to 0%"""
        await self.set_rollout_percentage(flag_name, 0.0)
        await self.audit.log("feature_flag.rollback", {
            "flag": flag_name,
            "reason": "emergency_rollback"
        })
```

### 4.4 Flag Audit Logging

```python
# All flag changes are audited
await audit.log("feature_flag.updated", {
    "flag": "streaming_mode",
    "old_value": {"rollout_percentage": 10.0},
    "new_value": {"rollout_percentage": 25.0},
    "changed_by": "user_abc123"
})

await audit.log("feature_flag.evaluated", {
    "flag": "advanced_analytics",
    "workspace_id": "ws_xyz789",
    "result": True,
    "reason": "tier_eligible"  # Or "whitelist", "rollout", "default"
})
```

---

## 5. Configuration Examples

### 5.1 Minimal Local Development

```toml
# ~/.feedback-arrow/config.development.toml

[server]
host = "127.0.0.1"
port = 8000
workers = 1

[database]
url = "sqlite:///./dev.db"

[cache]
backend = "memory"

[providers]
default = "ollama"

[providers.ollama]
enabled = true
endpoint = "http://localhost:11434"
model = "llama3.2"

[analysis]
batch_size = 10
enable_checkpointing = false

[observability]
log_format = "text"
log_level = "debug"
tracing_enabled = false
```

### 5.2 Production Deployment

```toml
# /etc/feedback-arrow/config.production.toml

[server]
host = "0.0.0.0"
port = 8000
workers = 8
tls_cert_path = "/etc/ssl/certs/feedback-arrow.crt"
tls_key_path = "/etc/ssl/private/feedback-arrow.key"
cors_origins = ["https://app.feedback-arrow.com"]

[database]
url = "postgresql://${DATABASE_USER}:${DATABASE_PASSWORD}@db.internal:5432/feedback_arrow"
pool_size = 20

[cache]
backend = "redis"
redis_url = "redis://redis.internal:6379"
enable_two_tier = true
disk_path = "/var/cache/feedback-arrow"

[providers]
default = "ollama"
routing_strategy = "local_first"

[providers.ollama]
enabled = true
endpoint = "http://ollama.internal:11434"
model = "llama3.2:70b"

[providers.openai]
enabled = true
priority = 10
api_key = "${OPENAI_API_KEY}"
model = "gpt-4o-mini"

[providers.anthropic]
enabled = true
priority = 11
api_key = "${ANTHROPIC_API_KEY}"
model = "claude-3-haiku-20240307"

[analysis]
batch_size = 100
max_concurrent_batches = 8
enable_checkpointing = true

[observability]
log_format = "json"
log_level = "info"
metrics_enabled = true
tracing_enabled = true
otlp_endpoint = "http://otel-collector.internal:4317"
trace_sample_rate = 0.1

[features]
streaming_mode = false
advanced_analytics = true
```

### 5.3 Multi-Tenant SaaS

```toml
# /etc/feedback-arrow/config.production.toml (SaaS specific)

[server]
host = "0.0.0.0"
port = 8000
workers = 16
max_request_size_mb = 500

[database]
url = "postgresql://${DATABASE_URL}"
pool_size = 50

[cache]
backend = "redis"
redis_url = "${REDIS_URL}"
redis_key_prefix = "fa:saas:"

[providers]
default = "ollama"
routing_strategy = "local_first"

# All providers enabled for tenant choice
[providers.ollama]
enabled = true
priority = 1

[providers.vllm]
enabled = true
priority = 2

[providers.openai]
enabled = true
priority = 10
api_key = "${OPENAI_API_KEY}"

[providers.anthropic]
enabled = true
priority = 11
api_key = "${ANTHROPIC_API_KEY}"

[analysis]
batch_size = 100
max_concurrent_batches = 16

# Feature flags for tiered access
[features]
streaming_mode = false
advanced_analytics = false  # Pro+ only
custom_models = false       # Enterprise only
```

---

## 6. Secret Reference Syntax

### 6.1 Environment Variable References

```toml
# Reference environment variables with ${VAR_NAME}
api_key = "${OPENAI_API_KEY}"
database_password = "${DATABASE_PASSWORD}"

# With default value
api_key = "${OPENAI_API_KEY:-sk-default}"

# Required (error if not set)
api_key = "${OPENAI_API_KEY:?API key is required}"
```

### 6.2 Secret Resolution

```python
class SecretResolver:
    """Resolve secret references in configuration"""

    PATTERN = re.compile(r'\$\{([^}]+)\}')

    def resolve(self, value: str) -> str:
        """Resolve ${VAR} references"""

        def replacer(match):
            ref = match.group(1)

            # Parse reference: VAR, VAR:-default, VAR:?error
            if ":-" in ref:
                var, default = ref.split(":-", 1)
                return os.environ.get(var, default)
            elif ":?" in ref:
                var, error = ref.split(":?", 1)
                value = os.environ.get(var)
                if not value:
                    raise ConfigError(error)
                return value
            else:
                return os.environ.get(ref, "")

        return self.PATTERN.sub(replacer, value)
```

---

## 7. Configuration Loading

### 7.1 Loader Implementation

```python
class ConfigLoader:
    """Load and merge configuration from all sources"""

    def load(self) -> FeedbackArrowConfig:
        # 1. Start with defaults
        config = FeedbackArrowConfig()

        # 2. Load system config
        system_config = self._load_toml("/etc/feedback-arrow/config.toml")
        if system_config:
            config = self._merge(config, system_config)

        # 3. Load user config
        user_config = self._load_toml(
            Path.home() / ".feedback-arrow" / "config.toml"
        )
        if user_config:
            config = self._merge(config, user_config)

        # 4. Load environment-specific config
        env = detect_environment()
        env_config = self._load_toml(
            Path.home() / ".feedback-arrow" / f"config.{env.value}.toml"
        )
        if env_config:
            config = self._merge(config, env_config)

        # 5. Apply environment variables
        config = self._apply_env_vars(config)

        # 6. Resolve secret references
        config = self._resolve_secrets(config)

        # 7. Validate final config
        return FeedbackArrowConfig(**config.model_dump())

    def _load_toml(self, path: Path) -> Optional[Dict]:
        if not path.exists():
            return None
        try:
            import tomllib
        except ImportError:
            import tomli as tomllib
        with open(path, "rb") as f:
            return tomllib.load(f)

    def _apply_env_vars(self, config: FeedbackArrowConfig) -> FeedbackArrowConfig:
        """Override config with FEEDBACK_ARROW_* env vars"""
        prefix = "FEEDBACK_ARROW_"
        config_dict = config.model_dump()

        for key, value in os.environ.items():
            if not key.startswith(prefix):
                continue

            # Convert FEEDBACK_ARROW_SECTION_KEY to section.key
            path = key[len(prefix):].lower().replace("_", ".")
            self._set_nested(config_dict, path, self._parse_value(value))

        return FeedbackArrowConfig(**config_dict)

    def _parse_value(self, value: str) -> Any:
        """Parse string value to appropriate type"""
        if value.lower() in ("true", "yes", "1"):
            return True
        if value.lower() in ("false", "no", "0"):
            return False
        try:
            return int(value)
        except ValueError:
            pass
        try:
            return float(value)
        except ValueError:
            pass
        return value
```

### 7.2 CLI Argument Override

```python
@click.command()
@click.option("--provider", help="Override default provider")
@click.option("--batch-size", type=int, help="Override batch size")
@click.option("--config", type=click.Path(), help="Config file path")
def analyze(provider, batch_size, config):
    # Load base config
    loader = ConfigLoader()
    if config:
        os.environ["FEEDBACK_ARROW_CONFIG"] = config
    cfg = loader.load()

    # Apply CLI overrides (highest priority)
    if provider:
        cfg.providers.default = provider
    if batch_size:
        cfg.analysis.batch_size = batch_size
```

---

## 8. Validation Rules

### 8.1 Cross-Field Validation

```python
class FeedbackArrowConfig(BaseModel):
    # ... fields ...

    @model_validator(mode="after")
    def validate_config(self) -> "FeedbackArrowConfig":
        # Validate Redis URL when Redis backend selected
        if self.cache.backend == "redis" and not self.cache.redis_url:
            raise ValueError("redis_url required when cache backend is 'redis'")

        # Validate at least one provider enabled
        providers = [
            self.providers.ollama,
            self.providers.openai,
            self.providers.anthropic,
            self.providers.vllm
        ]
        if not any(p.enabled for p in providers):
            raise ValueError("At least one provider must be enabled")

        # Validate default provider is enabled
        default = self.providers.default
        provider = getattr(self.providers, default, None)
        if provider and not provider.enabled:
            raise ValueError(f"Default provider '{default}' is not enabled")

        # Validate TLS in production
        if self.env == Environment.PRODUCTION:
            if not self.server.tls_cert_path:
                raise ValueError("TLS certificate required in production")

        return self
```

### 8.2 Validation Error Format

```python
class ConfigValidationError(Exception):
    def __init__(self, errors: List[Dict]):
        self.errors = errors
        super().__init__(self._format_errors())

    def _format_errors(self) -> str:
        lines = ["Configuration validation failed:"]
        for err in self.errors:
            lines.append(f"  - {err['loc']}: {err['msg']}")
        return "\n".join(lines)

# Example output:
# Configuration validation failed:
#   - cache.redis_url: redis_url required when cache backend is 'redis'
#   - providers: At least one provider must be enabled
```

---

**Cross-References:**
- Provider configuration: `LLM_PROVIDER_CONTRACT.md`
- Database schema: `STATE_STORE_SPEC.md`
- Feature flags in pipeline: `PIPELINE_DEFINITION.md`
- Tenant overrides: `MULTI_TENANCY_SPEC.md`
