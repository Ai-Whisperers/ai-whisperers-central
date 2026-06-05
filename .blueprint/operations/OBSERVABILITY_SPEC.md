# Operations Specification

**Version:** 1.0.0
**Date:** 2025-12-19
**Purpose:** Define operational aspects - lifecycle, error handling, SLOs, and runbooks
**Status:** Specification

---

## 1. LIFECYCLE MANAGEMENT

### 1.1 Application Lifecycle States

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   CREATED   │────▶│ INITIALIZING│────▶│    READY    │────▶│  RUNNING    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                               │                    │
                                               │                    │
                                               ▼                    ▼
                                        ┌─────────────┐     ┌─────────────┐
                                        │   DRAINING  │◀────│  STOPPING   │
                                        └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  TERMINATED │
                                        └─────────────┘
```

### 1.2 Startup Sequence

```python
class StartupSequence:
    """Application startup sequence"""

    async def run(self) -> None:
        """Execute startup in order"""

        # Phase 1: Configuration (no external deps)
        self.state = "initializing"
        await self._load_configuration()
        await self._validate_configuration()

        # Phase 2: Core Services
        await self._initialize_logging()
        await self._initialize_observability()
        await self._initialize_state_store()
        await self._initialize_persistence()

        # Phase 3: External Connections
        await self._connect_cache()
        await self._discover_llm_providers()
        await self._validate_secrets()

        # Phase 4: Pipeline Initialization
        await self._load_language_packs()
        await self._build_compute_graph()
        await self._warm_caches()

        # Phase 5: Ready
        self.state = "ready"
        await self._register_health_checks()
        await self._start_background_tasks()

        self.state = "running"

    async def _load_configuration(self) -> None:
        """Load configuration from files and environment"""
        self.config = load_config([
            Path("config/default.yaml"),
            Path("config/local.yaml"),
            Path.home() / ".feedback-arrow" / "config.yaml"
        ])
        self.config.merge_env_vars(prefix="FEEDBACK_ARROW_")

    async def _discover_llm_providers(self) -> None:
        """Discover and validate available LLM providers"""
        providers = []

        # Check local providers first
        if await self._check_ollama():
            providers.append(OllamaAdapter())
        if await self._check_vllm():
            providers.append(VLLMAdapter())

        # Check cloud providers if keys available
        if self.secrets.has("openai_api_key"):
            providers.append(OpenAIAdapter())
        if self.secrets.has("anthropic_api_key"):
            providers.append(AnthropicAdapter())

        if not providers:
            raise StartupError("No LLM providers available")

        self.llm_router = LLMRouter(providers, self.config.routing)

    async def _warm_caches(self) -> None:
        """Pre-warm caches for faster first request"""
        # Load language pack into memory
        lang_pack = await self.language_packs.load(self.config.language)

        # Precompile regex patterns
        for pattern in lang_pack.patterns.values():
            re.compile(pattern)

        # Load prompt templates
        await self.prompt_loader.preload(self.config.modules)
```

### 1.3 Shutdown Sequence

```python
class ShutdownSequence:
    """Graceful shutdown sequence"""

    DRAIN_TIMEOUT_SECONDS = 30
    FORCE_TIMEOUT_SECONDS = 10

    async def run(self, signal: str = "SIGTERM") -> None:
        """Execute graceful shutdown"""

        logger.info(f"Shutdown initiated: {signal}")
        self.state = "stopping"

        # Phase 1: Stop accepting new work
        await self._stop_accepting_requests()
        await self._deregister_from_load_balancer()

        # Phase 2: Drain in-flight work
        self.state = "draining"
        try:
            await asyncio.wait_for(
                self._drain_work(),
                timeout=self.DRAIN_TIMEOUT_SECONDS
            )
        except asyncio.TimeoutError:
            logger.warning("Drain timeout, proceeding with shutdown")

        # Phase 3: Save state
        await self._save_checkpoints()
        await self._flush_metrics()

        # Phase 4: Close connections
        await self._close_cache_connections()
        await self._close_database_connections()
        await self._close_llm_connections()

        # Phase 5: Cleanup
        await self._cleanup_temp_files()

        self.state = "terminated"
        logger.info("Shutdown complete")

    async def _drain_work(self) -> None:
        """Wait for in-flight work to complete"""
        while self.task_manager.has_running_tasks():
            logger.info(f"Draining: {self.task_manager.running_count()} tasks remaining")
            await asyncio.sleep(1)

    async def _save_checkpoints(self) -> None:
        """Save checkpoints for running tasks"""
        for task in self.task_manager.running_tasks():
            checkpoint = await task.create_checkpoint()
            await self.persistence.create("checkpoints", {
                "task_id": task.id,
                "checkpoint": checkpoint.to_dict()
            })
            logger.info(f"Saved checkpoint for task {task.id}")
```

### 1.4 Job Cancellation

```python
class TaskCancellation:
    """Handle task cancellation"""

    async def cancel_task(self, task_id: str, reason: str = "user_request") -> bool:
        """
        Cancel a running or pending task.

        Returns:
            True if successfully cancelled
        """
        task = await self.persistence.read("tasks", task_id)

        if task is None:
            raise TaskNotFoundError(task_id)

        if task["status"] in ("completed", "failed", "cancelled"):
            return False  # Already terminal state

        if task["status"] == "pending":
            # Not yet started, just update status
            await self.persistence.update("tasks", task_id, {
                "status": "cancelled",
                "cancelled_at": datetime.utcnow().isoformat(),
                "cancel_reason": reason
            })
            return True

        if task["status"] == "running":
            # Signal cancellation to running task
            runner = self.task_runners.get(task_id)
            if runner:
                runner.request_cancellation()

                # Wait for graceful stop
                try:
                    await asyncio.wait_for(runner.wait(), timeout=5.0)
                except asyncio.TimeoutError:
                    runner.force_cancel()

            # Save partial results if available
            if runner and runner.partial_results:
                await self._save_partial_results(task_id, runner.partial_results)

            await self.persistence.update("tasks", task_id, {
                "status": "cancelled",
                "cancelled_at": datetime.utcnow().isoformat(),
                "cancel_reason": reason,
                "partial_results": runner.partial_results_path if runner else None
            })
            return True

        return False
```

---

## 2. ERROR HANDLING STRATEGY

### 2.1 Error Classification

```python
from enum import Enum

class ErrorSeverity(Enum):
    """Error severity levels"""
    DEBUG = "debug"       # Expected, logged for debugging
    INFO = "info"         # Expected, informational
    WARNING = "warning"   # Unexpected but recoverable
    ERROR = "error"       # Failure requiring intervention
    CRITICAL = "critical" # System-level failure


class ErrorCategory(Enum):
    """Error categories for handling decisions"""
    TRANSIENT = "transient"       # Retry may succeed (network, rate limit)
    PERMANENT = "permanent"       # Will not succeed with retry (bad input)
    DEGRADED = "degraded"         # Partial functionality available
    SYSTEM = "system"             # Infrastructure failure


ERROR_CLASSIFICATION = {
    # Transient errors (retry)
    "ConnectionError": (ErrorCategory.TRANSIENT, ErrorSeverity.WARNING),
    "TimeoutError": (ErrorCategory.TRANSIENT, ErrorSeverity.WARNING),
    "RateLimitError": (ErrorCategory.TRANSIENT, ErrorSeverity.WARNING),
    "ProviderUnavailableError": (ErrorCategory.TRANSIENT, ErrorSeverity.WARNING),

    # Permanent errors (don't retry)
    "ValidationError": (ErrorCategory.PERMANENT, ErrorSeverity.ERROR),
    "SchemaError": (ErrorCategory.PERMANENT, ErrorSeverity.ERROR),
    "AuthenticationError": (ErrorCategory.PERMANENT, ErrorSeverity.ERROR),
    "FileNotFoundError": (ErrorCategory.PERMANENT, ErrorSeverity.ERROR),

    # Degraded (continue with reduced functionality)
    "CacheError": (ErrorCategory.DEGRADED, ErrorSeverity.WARNING),
    "TelemetryError": (ErrorCategory.DEGRADED, ErrorSeverity.INFO),

    # System errors (alert immediately)
    "OutOfMemoryError": (ErrorCategory.SYSTEM, ErrorSeverity.CRITICAL),
    "DiskFullError": (ErrorCategory.SYSTEM, ErrorSeverity.CRITICAL),
    "DatabaseConnectionError": (ErrorCategory.SYSTEM, ErrorSeverity.CRITICAL),
}
```

### 2.2 Retry Strategy

```python
from dataclasses import dataclass

@dataclass
class RetryConfig:
    """Retry configuration"""
    max_attempts: int = 3
    initial_delay_ms: int = 1000
    max_delay_ms: int = 30000
    exponential_base: float = 2.0
    jitter_factor: float = 0.1
    retryable_exceptions: tuple = (
        ConnectionError,
        TimeoutError,
        RateLimitError,
    )


class RetryHandler:
    """Handle retries with exponential backoff"""

    def __init__(self, config: RetryConfig):
        self.config = config

    async def execute_with_retry(
        self,
        operation: Callable,
        *args,
        context: str = "",
        **kwargs
    ) -> Any:
        """Execute operation with retry logic"""

        last_exception = None

        for attempt in range(1, self.config.max_attempts + 1):
            try:
                return await operation(*args, **kwargs)

            except self.config.retryable_exceptions as e:
                last_exception = e

                if attempt == self.config.max_attempts:
                    logger.error(f"[{context}] Max retries exceeded: {e}")
                    raise

                delay = self._calculate_delay(attempt)
                logger.warning(
                    f"[{context}] Attempt {attempt} failed: {e}. "
                    f"Retrying in {delay}ms"
                )
                await asyncio.sleep(delay / 1000)

            except Exception as e:
                # Non-retryable exception
                logger.error(f"[{context}] Non-retryable error: {e}")
                raise

    def _calculate_delay(self, attempt: int) -> int:
        """Calculate delay with exponential backoff and jitter"""
        base_delay = self.config.initial_delay_ms * (
            self.config.exponential_base ** (attempt - 1)
        )
        capped_delay = min(base_delay, self.config.max_delay_ms)

        # Add jitter
        jitter = capped_delay * self.config.jitter_factor * random.random()
        return int(capped_delay + jitter)
```

### 2.3 Circuit Breaker

```python
from enum import Enum

class CircuitState(Enum):
    CLOSED = "closed"      # Normal operation
    OPEN = "open"          # Failing, reject requests
    HALF_OPEN = "half_open"  # Testing if recovered


@dataclass
class CircuitBreakerConfig:
    failure_threshold: int = 5        # Failures before opening
    success_threshold: int = 3        # Successes in half-open before closing
    timeout_seconds: int = 60         # Time before half-open
    excluded_exceptions: tuple = ()   # Don't count these as failures


class CircuitBreaker:
    """Circuit breaker for external services"""

    def __init__(self, name: str, config: CircuitBreakerConfig, state_store: IStateStore):
        self.name = name
        self.config = config
        self.state_store = state_store

    async def call(self, operation: Callable, *args, **kwargs) -> Any:
        """Execute operation through circuit breaker"""

        state = await self._get_state()

        if state == CircuitState.OPEN:
            if await self._should_try_half_open():
                state = CircuitState.HALF_OPEN
            else:
                raise CircuitOpenError(f"Circuit {self.name} is open")

        try:
            result = await operation(*args, **kwargs)
            await self._record_success()
            return result

        except self.config.excluded_exceptions:
            raise

        except Exception as e:
            await self._record_failure()
            raise

    async def _get_state(self) -> CircuitState:
        failures = await self.state_store.get(f"circuit:{self.name}:failures")
        if failures and int(failures) >= self.config.failure_threshold:
            return CircuitState.OPEN
        return CircuitState.CLOSED

    async def _record_failure(self) -> None:
        await self.state_store.increment(
            f"circuit:{self.name}:failures",
            ttl=self.config.timeout_seconds
        )

    async def _record_success(self) -> None:
        await self.state_store.delete(f"circuit:{self.name}:failures")
```

### 2.4 Error Propagation

```python
class RowErrorHandler:
    """Handle row-level errors in batch processing"""

    def __init__(self, policy: ErrorPolicy):
        self.policy = policy
        self.errors: List[RowError] = []

    def handle_row_error(
        self,
        row_index: int,
        node_id: str,
        error: Exception
    ) -> Optional[Dict[str, Any]]:
        """
        Handle error for a specific row.

        Returns:
            Default values dict if policy allows continuation, None otherwise
        """
        self.errors.append(RowError(
            row_index=row_index,
            node_id=node_id,
            error_type=type(error).__name__,
            error_message=str(error),
            timestamp=datetime.utcnow()
        ))

        if self.policy == ErrorPolicy.FAIL_FAST:
            raise RowProcessingError(row_index, error) from error

        if self.policy == ErrorPolicy.CONTINUE:
            return self._get_defaults(node_id)

        if self.policy == ErrorPolicy.QUARANTINE:
            return None  # Row will be quarantined

        return None

    def _get_defaults(self, node_id: str) -> Dict[str, Any]:
        """Get default values for failed row"""
        return DEFAULT_VALUES.get(node_id, {})


DEFAULT_VALUES = {
    "sentiment": {
        "ai_sentiment_score": None,
        "ai_sentiment_category": "error"
    },
    "churn": {
        "churn_risk_score": None,
        "churn_risk_level": "unknown"
    },
    # ... other nodes
}
```

---

## 3. SERVICE LEVEL OBJECTIVES (SLOs)

### 3.1 SLO Definitions

```yaml
# slo/objectives.yaml

slos:
  # Availability
  availability:
    target: 99.9%  # 3 nines
    window: 30d
    definition: |
      Service responds to health check within 5 seconds
    error_budget: 43.2m/month

  # Latency
  api_latency:
    target: 95%
    threshold: 500ms
    window: 7d
    definition: |
      95% of API requests complete within 500ms
    exclusions:
      - /api/v1/analyze (async, returns immediately)
      - /api/v1/tasks/{id}/results (file download)

  sync_analysis_latency:
    target: 90%
    threshold: 30s
    window: 7d
    definition: |
      90% of synchronous analysis requests complete within 30 seconds
    conditions:
      - file_rows <= 100

  # Throughput
  analysis_throughput:
    target: 95%
    threshold: 100 rows/second
    window: 24h
    definition: |
      System processes at least 100 rows/second when not rate-limited

  # Error Rate
  error_rate:
    target: 99%
    threshold: 1%
    window: 24h
    definition: |
      Less than 1% of analysis requests result in errors
    exclusions:
      - Client errors (4xx)
      - Rate limit errors

  # Data Quality
  analysis_accuracy:
    target: 95%
    window: 30d
    definition: |
      95% of sentiment scores within ±1 of human-labeled ground truth
    measurement: Golden dataset comparison
```

### 3.2 SLI Metrics

```python
# Metrics for SLI measurement

SLI_METRICS = {
    "availability": {
        "metric": "health_check_success_rate",
        "query": "rate(health_check_success[5m]) / rate(health_check_total[5m])",
        "good_threshold": 1.0
    },
    "api_latency": {
        "metric": "http_request_duration_seconds",
        "query": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
        "good_threshold": 0.5
    },
    "error_rate": {
        "metric": "analysis_error_rate",
        "query": "rate(analysis_errors[5m]) / rate(analysis_total[5m])",
        "good_threshold": 0.01
    }
}

class SLOMonitor:
    """Monitor SLO compliance"""

    def __init__(self, objectives: Dict[str, SLO], observability: IObservability):
        self.objectives = objectives
        self.observability = observability

    async def check_compliance(self) -> Dict[str, SLOStatus]:
        """Check current SLO compliance"""
        results = {}

        for name, slo in self.objectives.items():
            current_value = await self._measure_sli(slo)
            budget_remaining = self._calculate_budget(slo, current_value)

            results[name] = SLOStatus(
                name=name,
                target=slo.target,
                current=current_value,
                compliant=current_value >= slo.target,
                budget_remaining=budget_remaining,
                budget_burn_rate=self._calculate_burn_rate(slo)
            )

        return results

    def _calculate_budget(self, slo: SLO, current: float) -> float:
        """Calculate remaining error budget"""
        allowed_failures = 1 - slo.target
        actual_failures = 1 - current
        return max(0, (allowed_failures - actual_failures) / allowed_failures)
```

### 3.3 Alerting

```yaml
# alerts/slo_alerts.yaml

alerts:
  # Availability
  - name: AvailabilityBudgetBurn
    condition: slo_budget_remaining{slo="availability"} < 0.5
    severity: warning
    message: "Availability error budget 50% consumed"
    runbook: runbooks/availability.md

  - name: AvailabilityCritical
    condition: slo_budget_remaining{slo="availability"} < 0.1
    severity: critical
    message: "Availability error budget nearly exhausted"
    runbook: runbooks/availability.md

  # Latency
  - name: LatencyDegraded
    condition: histogram_quantile(0.95, http_request_duration_seconds) > 1
    for: 5m
    severity: warning
    message: "P95 latency exceeds 1 second"
    runbook: runbooks/latency.md

  # Error Rate
  - name: HighErrorRate
    condition: rate(analysis_errors[5m]) / rate(analysis_total[5m]) > 0.05
    for: 5m
    severity: critical
    message: "Error rate exceeds 5%"
    runbook: runbooks/errors.md

  # LLM Provider
  - name: AllProvidersDown
    condition: sum(llm_provider_healthy) == 0
    severity: critical
    message: "No LLM providers available"
    runbook: runbooks/llm_providers.md

  - name: LocalProviderDown
    condition: llm_provider_healthy{provider="ollama"} == 0
    for: 2m
    severity: warning
    message: "Ollama provider unavailable"
    runbook: runbooks/ollama.md
```

---

## 4. RUNBOOKS

### 4.1 Runbook: High Error Rate

```markdown
# Runbook: High Error Rate

## Alert
- **Name:** HighErrorRate
- **Condition:** Error rate > 5% for 5 minutes
- **Severity:** Critical

## Symptoms
- Increased 5xx responses
- Failed analysis jobs
- Customer complaints

## Diagnosis Steps

### 1. Check Error Distribution
```bash
# Get error breakdown by type
feedback-arrow metrics errors --last 1h --group-by type
```

### 2. Check LLM Provider Health
```bash
feedback-arrow providers health --all
```

### 3. Check Recent Logs
```bash
journalctl -u feedback-arrow --since "10 minutes ago" | grep ERROR
```

### 4. Check Resource Usage
```bash
feedback-arrow metrics system  # CPU, memory, disk
```

## Resolution Steps

### If LLM Provider Errors
1. Check provider status page
2. Switch to fallback provider:
   ```bash
   feedback-arrow providers set-default openai
   ```
3. If all providers down, enable degraded mode:
   ```bash
   feedback-arrow config set llm.fallback_to_lexicon true
   ```

### If Resource Exhaustion
1. Scale horizontally if possible
2. Reduce batch size:
   ```bash
   feedback-arrow config set processing.batch_size 25
   ```
3. Enable rate limiting:
   ```bash
   feedback-arrow config set api.rate_limit 10/min
   ```

### If Invalid Input Data
1. Check recent uploads for patterns
2. Tighten input validation if needed
3. Contact customer if specific to one source

## Escalation
- If not resolved in 15 minutes, escalate to on-call engineer
- If affecting > 50% of traffic, declare incident
```

### 4.2 Runbook: LLM Provider Unavailable

```markdown
# Runbook: LLM Provider Unavailable

## Alert
- **Name:** AllProvidersDown or LocalProviderDown
- **Severity:** Critical/Warning

## Diagnosis Steps

### 1. Check Ollama Status
```bash
systemctl status ollama
ollama list  # Check if models are loaded
curl http://localhost:11434/api/tags  # API health
```

### 2. Check Cloud Provider Status
```bash
# OpenAI
curl -H "Authorization: Bearer $OPENAI_API_KEY" \
  https://api.openai.com/v1/models

# Anthropic
curl -H "x-api-key: $ANTHROPIC_API_KEY" \
  https://api.anthropic.com/v1/messages -d '{}'
```

### 3. Check Network
```bash
ping api.openai.com
nc -zv api.anthropic.com 443
```

## Resolution Steps

### Ollama Down
1. Restart Ollama:
   ```bash
   systemctl restart ollama
   ```
2. Reload model:
   ```bash
   ollama run llama3:8b
   ```
3. If GPU issues:
   ```bash
   nvidia-smi  # Check GPU status
   ```

### Cloud Provider Issues
1. Check provider status page
2. Switch routing strategy:
   ```bash
   feedback-arrow config set llm.routing_strategy failover
   ```
3. If rate limited, wait or reduce throughput

### Degraded Mode
Enable lexicon-only mode (no LLM):
```bash
feedback-arrow config set llm.fallback_mode lexicon_only
```
Note: This reduces analysis quality significantly.

## Recovery
1. Verify provider is responding
2. Clear circuit breaker:
   ```bash
   feedback-arrow providers reset-circuit ollama
   ```
3. Monitor error rates for 10 minutes
```

### 4.3 Runbook: Database Connection Issues

```markdown
# Runbook: Database Connection Issues

## Alert
- **Name:** DatabaseConnectionError
- **Severity:** Critical

## Symptoms
- Tasks not persisting
- Job history unavailable
- API returning 500 errors

## Diagnosis Steps

### 1. Check Database Connection
```bash
# DuckDB
ls -la data/feedback_arrow.duckdb
duckdb data/feedback_arrow.duckdb "SELECT 1"

# PostgreSQL
psql $DATABASE_URL -c "SELECT 1"
```

### 2. Check Disk Space
```bash
df -h /data
```

### 3. Check File Locks
```bash
lsof data/feedback_arrow.duckdb
```

## Resolution Steps

### If Disk Full
1. Clear old checkpoints:
   ```bash
   find checkpoints/ -mtime +7 -delete
   ```
2. Clear old exports:
   ```bash
   find exports/ -mtime +30 -delete
   ```
3. Compact database:
   ```bash
   duckdb data/feedback_arrow.duckdb "VACUUM"
   ```

### If Corrupted Database
1. Stop application
2. Restore from backup:
   ```bash
   cp /backups/latest/feedback_arrow.duckdb data/
   ```
3. Restart application

### If Lock Contention
1. Find blocking process:
   ```bash
   lsof data/feedback_arrow.duckdb
   ```
2. Kill if stuck:
   ```bash
   kill -9 <PID>
   ```
3. Remove stale lock file:
   ```bash
   rm data/feedback_arrow.duckdb.wal
   ```
```

---

## 5. CAPACITY PLANNING

### 5.1 Resource Formulas

```python
# Capacity planning formulas

def estimate_memory_mb(rows: int, columns: int = 36, avg_comment_len: int = 200) -> int:
    """Estimate memory requirement for analysis"""
    # Arrow Table overhead
    row_size = columns * 8 + avg_comment_len * 2  # Rough estimate
    table_size = rows * row_size

    # Processing overhead (2x for intermediate results)
    processing_overhead = table_size * 2

    # LLM response caching
    cache_size = rows * 500  # ~500 bytes per response

    total_bytes = table_size + processing_overhead + cache_size
    return int(total_bytes / (1024 * 1024)) + 256  # +256MB baseline


def estimate_duration_seconds(
    rows: int,
    llm_tokens_per_row: int = 500,
    tokens_per_second: int = 100,
    parallelism: int = 4
) -> int:
    """Estimate processing duration"""
    # Skip duplicates (assume 10% duplicate rate)
    unique_rows = int(rows * 0.9)

    # LLM processing time
    total_tokens = unique_rows * llm_tokens_per_row
    llm_time = total_tokens / tokens_per_second / parallelism

    # Non-LLM processing (~1ms per row)
    processing_time = rows * 0.001

    return int(llm_time + processing_time)


def estimate_cost_usd(
    rows: int,
    provider: str = "ollama",
    cost_per_1k_input: float = 0,
    cost_per_1k_output: float = 0
) -> float:
    """Estimate processing cost"""
    if provider == "ollama":
        return 0.0  # Free

    unique_rows = int(rows * 0.9)
    input_tokens = unique_rows * 300  # Prompt tokens
    output_tokens = unique_rows * 200  # Response tokens

    cost = (
        (input_tokens / 1000) * cost_per_1k_input +
        (output_tokens / 1000) * cost_per_1k_output
    )
    return round(cost, 4)
```

### 5.2 Scaling Guidelines

```yaml
# Scaling recommendations by workload

small:
  description: "< 10,000 rows/day"
  resources:
    cpu: 2
    memory: 4GB
    gpu: optional
  providers:
    - ollama (7B model)
  deployment: single instance

medium:
  description: "10,000 - 100,000 rows/day"
  resources:
    cpu: 4
    memory: 16GB
    gpu: recommended (8GB VRAM)
  providers:
    - ollama (13B model) or vLLM
    - cloud fallback
  deployment: single instance with queue

large:
  description: "100,000 - 1M rows/day"
  resources:
    cpu: 8
    memory: 32GB
    gpu: required (24GB VRAM)
  providers:
    - vLLM with batching
    - cloud for overflow
  deployment: horizontal scaling (2-4 instances)

enterprise:
  description: "> 1M rows/day"
  resources:
    cpu: 16+
    memory: 64GB+
    gpu: multiple or A100
  providers:
    - dedicated vLLM cluster
    - reserved cloud capacity
  deployment: k8s with auto-scaling
```

---

## 6. DISASTER RECOVERY

### 6.1 Backup Strategy

```yaml
# backup/strategy.yaml

backups:
  database:
    type: continuous
    target: duckdb
    frequency: hourly
    retention: 30 days
    location: /backups/database/

  checkpoints:
    type: snapshot
    target: checkpoints/
    frequency: on_completion
    retention: 7 days
    location: /backups/checkpoints/

  config:
    type: version_controlled
    target: config/
    location: git repository

  language_packs:
    type: versioned
    target: language_packs/
    frequency: on_change
    location: /backups/language_packs/

recovery_point_objective: 1 hour  # Max data loss
recovery_time_objective: 30 minutes  # Max downtime
```

### 6.2 Recovery Procedures

```markdown
# Disaster Recovery Procedure

## Scenario: Complete Data Loss

### 1. Deploy Fresh Instance
```bash
docker run -d --name feedback-arrow \
  -v /data:/app/data \
  feedback-arrow:latest
```

### 2. Restore Database
```bash
# Find latest backup
ls -lt /backups/database/ | head -5

# Restore
cp /backups/database/latest.duckdb /data/feedback_arrow.duckdb
```

### 3. Restore Configuration
```bash
git clone git@github.com:org/feedback-arrow-config.git /config
```

### 4. Verify Health
```bash
feedback-arrow health
feedback-arrow providers list
```

### 5. Resume In-Flight Jobs
```bash
# List pending checkpoints
ls /backups/checkpoints/

# Resume each
for cp in /backups/checkpoints/*; do
  feedback-arrow analyze --resume $cp
done
```

## Scenario: Provider Outage

See Runbook: LLM Provider Unavailable

## Scenario: Datacenter Failure

1. Failover to secondary region (if configured)
2. Update DNS to point to secondary
3. Restore from cross-region backups
4. Verify data integrity
```

---

## SUMMARY

```
OPERATIONS:
├── Lifecycle Management
│   ├── Startup: Config → Services → Connections → Pipeline → Ready
│   ├── Shutdown: Stop → Drain → Checkpoint → Close → Cleanup
│   └── Cancellation: Signal → Graceful → Force → Save partial
│
├── Error Handling
│   ├── Classification: Transient | Permanent | Degraded | System
│   ├── Retry: Exponential backoff with jitter
│   ├── Circuit Breaker: Closed → Open → Half-Open
│   └── Row-Level: Fail-fast | Continue | Quarantine
│
├── SLOs
│   ├── Availability: 99.9%
│   ├── Latency: P95 < 500ms
│   ├── Error Rate: < 1%
│   └── Throughput: 100 rows/sec
│
├── Runbooks
│   ├── High Error Rate
│   ├── LLM Provider Down
│   └── Database Issues
│
├── Capacity Planning
│   ├── Memory formula
│   ├── Duration formula
│   └── Cost formula
│
└── Disaster Recovery
    ├── Hourly database backups
    ├── RPO: 1 hour
    └── RTO: 30 minutes
```

---

## 7. DEPLOYMENT PROCEDURES

### 7.1 Deployment Strategies

```yaml
# deployment/strategies.yaml

strategies:
  blue_green:
    description: "Two identical production environments with instant switch"
    use_when:
      - Major version releases
      - Breaking schema changes
      - High-risk deployments
    rollback_time: "< 1 minute"

  canary:
    description: "Gradual rollout with traffic splitting"
    use_when:
      - Minor version releases
      - Feature flag-gated changes
      - Performance-sensitive changes
    rollback_time: "< 2 minutes"

  rolling:
    description: "Sequential instance replacement"
    use_when:
      - Configuration changes
      - Patch releases
      - Low-risk updates
    rollback_time: "< 5 minutes"
```

### 7.2 Blue-Green Deployment

```
┌─────────────────────────────────────────────────────────────────┐
│                         LOAD BALANCER                            │
│                              │                                   │
│              ┌───────────────┴───────────────┐                   │
│              ▼                               ▼                   │
│   ┌──────────────────┐           ┌──────────────────┐           │
│   │   BLUE (Active)  │           │  GREEN (Standby) │           │
│   │   Version: 2.0.0 │           │  Version: 2.1.0  │           │
│   │   100% Traffic   │           │   0% Traffic     │           │
│   └──────────────────┘           └──────────────────┘           │
│              │                               │                   │
│              └───────────────┬───────────────┘                   │
│                              ▼                                   │
│                   ┌──────────────────┐                           │
│                   │  SHARED DATABASE │                           │
│                   │  (Read Replicas) │                           │
│                   └──────────────────┘                           │
└─────────────────────────────────────────────────────────────────┘
```

```python
from dataclasses import dataclass
from enum import Enum

class DeploymentSlot(Enum):
    BLUE = "blue"
    GREEN = "green"

@dataclass
class BlueGreenDeployment:
    """Blue-Green deployment procedure"""

    active_slot: DeploymentSlot
    inactive_slot: DeploymentSlot

    async def deploy(self, version: str) -> DeploymentResult:
        """
        Execute blue-green deployment.

        Steps:
        1. Deploy new version to inactive slot
        2. Run health checks on inactive slot
        3. Run smoke tests against inactive slot
        4. Switch traffic to inactive slot
        5. Monitor for errors
        6. Promote inactive to active
        """

        # Step 1: Deploy to inactive slot
        await self._deploy_to_slot(self.inactive_slot, version)

        # Step 2: Health checks
        if not await self._health_check(self.inactive_slot, timeout_seconds=60):
            raise DeploymentError("Health check failed on new deployment")

        # Step 3: Smoke tests
        smoke_results = await self._run_smoke_tests(self.inactive_slot)
        if not smoke_results.passed:
            raise DeploymentError(f"Smoke tests failed: {smoke_results.failures}")

        # Step 4: Switch traffic (atomic)
        await self._switch_traffic(
            from_slot=self.active_slot,
            to_slot=self.inactive_slot
        )

        # Step 5: Monitor for errors (5 minute window)
        error_rate = await self._monitor_error_rate(
            slot=self.inactive_slot,
            duration_seconds=300,
            threshold=0.05  # 5% error rate threshold
        )

        if error_rate > 0.05:
            # Automatic rollback
            await self._switch_traffic(
                from_slot=self.inactive_slot,
                to_slot=self.active_slot
            )
            raise DeploymentError(f"Error rate {error_rate:.2%} exceeded threshold")

        # Step 6: Promote
        self.active_slot, self.inactive_slot = self.inactive_slot, self.active_slot

        return DeploymentResult(
            success=True,
            version=version,
            active_slot=self.active_slot,
            deployment_time_seconds=self._elapsed_time()
        )

    async def rollback(self) -> RollbackResult:
        """Instant rollback by switching traffic back"""
        await self._switch_traffic(
            from_slot=self.active_slot,
            to_slot=self.inactive_slot
        )
        self.active_slot, self.inactive_slot = self.inactive_slot, self.active_slot
        return RollbackResult(success=True, rollback_time_seconds=5)
```

### 7.3 Canary Deployment

```python
@dataclass
class CanaryConfig:
    """Canary deployment configuration"""
    initial_percentage: float = 5.0      # Start with 5% traffic
    increment_percentage: float = 10.0   # Increase by 10% each step
    evaluation_period_seconds: int = 300 # 5 minutes between steps
    error_threshold: float = 0.02        # 2% error rate triggers rollback
    latency_threshold_p95_ms: int = 1000 # P95 latency threshold


class CanaryDeployment:
    """Canary deployment with gradual rollout"""

    def __init__(self, config: CanaryConfig, load_balancer: ILoadBalancer):
        self.config = config
        self.load_balancer = load_balancer

    async def deploy(self, version: str) -> DeploymentResult:
        """
        Execute canary deployment.

        Traffic progression: 5% → 15% → 25% → 50% → 100%
        """

        # Deploy canary instance
        canary_instance = await self._deploy_canary(version)

        current_percentage = 0.0

        try:
            while current_percentage < 100.0:
                # Increment traffic
                next_percentage = min(
                    current_percentage + self.config.increment_percentage,
                    100.0
                )
                if current_percentage == 0:
                    next_percentage = self.config.initial_percentage

                await self.load_balancer.set_canary_weight(next_percentage)
                current_percentage = next_percentage

                logger.info(f"Canary at {current_percentage}% traffic")

                # Evaluate metrics during observation period
                metrics = await self._evaluate_canary(
                    duration_seconds=self.config.evaluation_period_seconds
                )

                if not self._metrics_acceptable(metrics):
                    raise CanaryFailedError(
                        f"Canary failed at {current_percentage}%: {metrics}"
                    )

            # Full rollout successful
            await self._promote_canary(canary_instance)
            return DeploymentResult(success=True, version=version)

        except CanaryFailedError:
            # Rollback canary
            await self.load_balancer.set_canary_weight(0.0)
            await self._terminate_canary(canary_instance)
            raise

    def _metrics_acceptable(self, metrics: CanaryMetrics) -> bool:
        """Check if canary metrics are within acceptable bounds"""
        return (
            metrics.error_rate <= self.config.error_threshold and
            metrics.latency_p95_ms <= self.config.latency_threshold_p95_ms
        )


@dataclass
class CanaryMetrics:
    """Metrics collected during canary evaluation"""
    error_rate: float
    latency_p50_ms: int
    latency_p95_ms: int
    latency_p99_ms: int
    request_count: int
    success_count: int
    failure_count: int
```

### 7.4 Database Migration Strategy

```python
from alembic import command
from alembic.config import Config as AlembicConfig

class MigrationManager:
    """
    Database migration using Alembic with zero-downtime patterns.

    Key Principles:
    1. Additive only - never remove/rename in same release
    2. Dual-write pattern for schema changes
    3. Backfill data before removing old schema
    4. All migrations must be reversible
    """

    def __init__(self, database_url: str):
        self.alembic_cfg = AlembicConfig("alembic.ini")
        self.alembic_cfg.set_main_option("sqlalchemy.url", database_url)

    async def migrate(
        self,
        target_revision: str = "head",
        dry_run: bool = False
    ) -> MigrationResult:
        """
        Execute database migration.

        For zero-downtime, migrations follow expand/contract pattern:
        - Release N: Add new columns (expand)
        - Release N+1: Dual-write to both old and new
        - Release N+2: Read from new, write to new only
        - Release N+3: Drop old columns (contract)
        """

        # Check current state
        current = self._get_current_revision()
        pending = self._get_pending_migrations(current, target_revision)

        if not pending:
            return MigrationResult(success=True, applied=[])

        # Validate migrations are reversible
        for migration in pending:
            if not migration.has_downgrade:
                raise MigrationError(
                    f"Migration {migration.revision} is not reversible"
                )

        if dry_run:
            return MigrationResult(
                success=True,
                applied=[],
                pending=[m.revision for m in pending]
            )

        # Take backup before migration
        backup_path = await self._create_backup()

        try:
            # Apply migrations
            command.upgrade(self.alembic_cfg, target_revision)

            # Verify data integrity
            if not await self._verify_data_integrity():
                raise MigrationError("Data integrity check failed")

            return MigrationResult(
                success=True,
                applied=[m.revision for m in pending],
                backup_path=backup_path
            )

        except Exception as e:
            # Rollback on failure
            logger.error(f"Migration failed: {e}")
            command.downgrade(self.alembic_cfg, current)
            raise

    async def rollback(self, steps: int = 1) -> MigrationResult:
        """Rollback specified number of migrations"""
        current = self._get_current_revision()
        target = self._get_revision_minus_n(current, steps)

        command.downgrade(self.alembic_cfg, target)

        return MigrationResult(
            success=True,
            rolled_back=steps,
            current_revision=target
        )


# Example migration following expand/contract pattern
"""
# migrations/versions/001_add_tenant_id_column.py

def upgrade():
    # EXPAND: Add new column as nullable first
    op.add_column(
        'analyses',
        sa.Column('tenant_id', sa.String(26), nullable=True)
    )
    # Add index for performance
    op.create_index('ix_analyses_tenant_id', 'analyses', ['tenant_id'])


def downgrade():
    op.drop_index('ix_analyses_tenant_id')
    op.drop_column('analyses', 'tenant_id')


# migrations/versions/002_backfill_tenant_id.py

def upgrade():
    # BACKFILL: Populate existing rows with default tenant
    op.execute(
        "UPDATE analyses SET tenant_id = 'default' WHERE tenant_id IS NULL"
    )


def downgrade():
    pass  # Backfill is not reversed


# migrations/versions/003_make_tenant_id_required.py

def upgrade():
    # CONTRACT: Make column non-nullable after backfill
    op.alter_column(
        'analyses',
        'tenant_id',
        nullable=False
    )


def downgrade():
    op.alter_column(
        'analyses',
        'tenant_id',
        nullable=True
    )
"""
```

### 7.5 Rollback Procedure

```yaml
# deployment/rollback.yaml

rollback:
  target_time: "< 5 minutes"

  automatic_triggers:
    - error_rate_spike: "> 10% increase in 2 minutes"
    - latency_spike: "> 2x P95 latency for 5 minutes"
    - health_check_failures: "> 3 consecutive failures"
    - crash_loop: "> 5 restarts in 10 minutes"

  manual_triggers:
    - cli: "feedback-arrow deploy rollback"
    - api: "POST /admin/rollback"
    - dashboard: "Rollback button in deployment dashboard"

  steps:
    blue_green:
      1: "Switch load balancer to previous slot"
      2: "Verify traffic flowing to previous version"
      3: "Mark rollback in deployment history"
      4: "Alert on-call of rollback event"
      time: "< 1 minute"

    canary:
      1: "Set canary weight to 0%"
      2: "Terminate canary instances"
      3: "Verify all traffic on stable version"
      4: "Mark deployment as failed"
      time: "< 2 minutes"

    rolling:
      1: "Stop deployment progress"
      2: "Deploy previous version to updated instances"
      3: "Wait for health checks on each instance"
      4: "Verify service stability"
      time: "< 5 minutes"
```

```python
class RollbackController:
    """Manage deployment rollbacks"""

    ROLLBACK_TIMEOUT_SECONDS = 300  # 5 minutes

    async def rollback(
        self,
        deployment_id: str,
        reason: str = "manual"
    ) -> RollbackResult:
        """
        Execute rollback for a deployment.

        Args:
            deployment_id: The deployment to rollback
            reason: Why rollback was triggered

        Returns:
            RollbackResult with status and timing
        """
        deployment = await self.deployments.get(deployment_id)

        if deployment.strategy == DeploymentStrategy.BLUE_GREEN:
            result = await self._rollback_blue_green(deployment)
        elif deployment.strategy == DeploymentStrategy.CANARY:
            result = await self._rollback_canary(deployment)
        elif deployment.strategy == DeploymentStrategy.ROLLING:
            result = await self._rollback_rolling(deployment)
        else:
            raise ValueError(f"Unknown strategy: {deployment.strategy}")

        # Record rollback event
        await self._record_rollback(
            deployment_id=deployment_id,
            reason=reason,
            result=result,
            triggered_by=self._get_current_user()
        )

        # Alert on-call
        await self.alerting.send_alert(
            severity="warning",
            title=f"Deployment {deployment_id} rolled back",
            message=f"Reason: {reason}. Rollback completed in {result.duration_seconds}s"
        )

        return result

    async def _rollback_blue_green(self, deployment: Deployment) -> RollbackResult:
        """Instant traffic switch"""
        start = time.time()

        await self.load_balancer.switch_to_slot(deployment.previous_slot)

        return RollbackResult(
            success=True,
            duration_seconds=time.time() - start,
            previous_version=deployment.previous_version,
            rolled_back_version=deployment.version
        )
```

### 7.6 Zero-Downtime Deployment Checklist

```yaml
# deployment/checklist.yaml

pre_deployment:
  - name: "Run full test suite"
    command: "pytest tests/ -v"
    required: true

  - name: "Verify database migrations are reversible"
    command: "alembic upgrade head && alembic downgrade -1 && alembic upgrade head"
    required: true

  - name: "Check for breaking API changes"
    command: "feedback-arrow api diff --fail-on-breaking"
    required: true

  - name: "Verify feature flags are set correctly"
    command: "feedback-arrow flags verify-deployment"
    required: false

  - name: "Ensure rollback artifacts exist"
    command: "ls -la /deploy/rollback/"
    required: true

  - name: "Notify stakeholders"
    command: "feedback-arrow notify deployment-starting"
    required: false

during_deployment:
  - name: "Apply database migrations (expand phase)"
    order: 1

  - name: "Deploy new application version"
    order: 2

  - name: "Health check new instances"
    order: 3
    timeout: 60s

  - name: "Run smoke tests"
    order: 4
    timeout: 120s

  - name: "Switch traffic (gradual or instant)"
    order: 5

  - name: "Monitor error rate and latency"
    order: 6
    duration: 300s

post_deployment:
  - name: "Verify SLOs are met"
    command: "feedback-arrow slo check --last 5m"
    required: true

  - name: "Run integration tests against production"
    command: "pytest tests/integration/ --env=prod"
    required: false

  - name: "Tag deployment in observability platform"
    command: "feedback-arrow metrics tag-deployment"
    required: true

  - name: "Update deployment documentation"
    command: "feedback-arrow docs update-changelog"
    required: false

  - name: "Notify stakeholders of completion"
    command: "feedback-arrow notify deployment-complete"
    required: false

rollback_conditions:
  automatic:
    - "Error rate increases by more than 10%"
    - "P95 latency doubles"
    - "Health check fails 3 consecutive times"

  manual:
    - "Customer reports critical functionality broken"
    - "Security vulnerability discovered"
    - "Data integrity issues detected"
```

---

## 8. ALERTING POLICIES

### 8.1 Alert Severity Levels

```yaml
# alerting/severity.yaml

severity_levels:
  P1_CRITICAL:
    description: "Service is down or severely degraded"
    response_time: "Immediate (< 5 minutes)"
    examples:
      - "All LLM providers unavailable"
      - "Database unreachable"
      - "Error rate > 50%"
      - "Complete service outage"
    notification:
      channels: [pagerduty, slack_urgent, phone]
      repeat_interval: 5m
      escalation: true

  P2_HIGH:
    description: "Significant degradation affecting users"
    response_time: "< 15 minutes"
    examples:
      - "Single LLM provider down"
      - "Error rate > 10%"
      - "P95 latency > 5 seconds"
      - "Disk usage > 90%"
    notification:
      channels: [pagerduty, slack_alerts]
      repeat_interval: 15m
      escalation: true

  P3_MEDIUM:
    description: "Degradation that may impact users"
    response_time: "< 1 hour"
    examples:
      - "Cache hit rate dropped significantly"
      - "Error rate > 5%"
      - "Memory usage trending high"
      - "Queue depth increasing"
    notification:
      channels: [slack_alerts, email]
      repeat_interval: 1h
      escalation: false

  P4_LOW:
    description: "Minor issue or informational"
    response_time: "Next business day"
    examples:
      - "Deprecation warning triggered"
      - "Certificate expiring in 30 days"
      - "Disk usage > 70%"
    notification:
      channels: [slack_info, email]
      repeat_interval: 24h
      escalation: false
```

### 8.2 Alert Routing

```python
from dataclasses import dataclass
from enum import Enum
from typing import List, Optional

class AlertChannel(Enum):
    PAGERDUTY = "pagerduty"
    SLACK_URGENT = "slack_urgent"     # #alerts-urgent
    SLACK_ALERTS = "slack_alerts"     # #alerts
    SLACK_INFO = "slack_info"         # #alerts-info
    EMAIL = "email"
    SMS = "sms"
    PHONE = "phone"


@dataclass
class AlertRoute:
    """Routing rule for alerts"""
    name: str
    match: dict                       # Alert labels to match
    channels: List[AlertChannel]
    escalation_policy: Optional[str]  # PagerDuty policy ID


class AlertRouter:
    """Route alerts to appropriate channels based on rules"""

    ROUTES = [
        # Critical infrastructure alerts → immediate phone call
        AlertRoute(
            name="critical_infra",
            match={"severity": "P1", "category": "infrastructure"},
            channels=[AlertChannel.PAGERDUTY, AlertChannel.PHONE, AlertChannel.SLACK_URGENT],
            escalation_policy="infra_critical"
        ),

        # Critical application alerts → PagerDuty + Slack
        AlertRoute(
            name="critical_app",
            match={"severity": "P1", "category": "application"},
            channels=[AlertChannel.PAGERDUTY, AlertChannel.SLACK_URGENT],
            escalation_policy="app_critical"
        ),

        # High severity → PagerDuty + Slack
        AlertRoute(
            name="high_severity",
            match={"severity": "P2"},
            channels=[AlertChannel.PAGERDUTY, AlertChannel.SLACK_ALERTS],
            escalation_policy="standard"
        ),

        # Medium severity → Slack + Email
        AlertRoute(
            name="medium_severity",
            match={"severity": "P3"},
            channels=[AlertChannel.SLACK_ALERTS, AlertChannel.EMAIL],
            escalation_policy=None
        ),

        # Low severity → Info channel + Email
        AlertRoute(
            name="low_severity",
            match={"severity": "P4"},
            channels=[AlertChannel.SLACK_INFO, AlertChannel.EMAIL],
            escalation_policy=None
        ),

        # Tenant-specific alerts → Tenant's configured channels
        AlertRoute(
            name="tenant_alerts",
            match={"tenant_id": "*"},  # Any tenant
            channels=[],  # Determined by tenant config
            escalation_policy=None
        ),
    ]

    async def route_alert(self, alert: Alert) -> List[AlertNotification]:
        """Route alert to appropriate channels"""
        notifications = []

        for route in self.ROUTES:
            if self._matches(alert, route.match):
                for channel in route.channels:
                    notification = await self._send_to_channel(
                        alert=alert,
                        channel=channel,
                        escalation_policy=route.escalation_policy
                    )
                    notifications.append(notification)
                break  # First matching route wins

        return notifications

    async def _send_to_channel(
        self,
        alert: Alert,
        channel: AlertChannel,
        escalation_policy: Optional[str]
    ) -> AlertNotification:
        """Send alert to specific channel"""

        if channel == AlertChannel.PAGERDUTY:
            return await self._send_pagerduty(alert, escalation_policy)
        elif channel in (AlertChannel.SLACK_URGENT, AlertChannel.SLACK_ALERTS, AlertChannel.SLACK_INFO):
            return await self._send_slack(alert, channel)
        elif channel == AlertChannel.EMAIL:
            return await self._send_email(alert)
        elif channel == AlertChannel.PHONE:
            return await self._send_phone_call(alert)
        elif channel == AlertChannel.SMS:
            return await self._send_sms(alert)
```

### 8.3 Alert Deduplication

```python
@dataclass
class DeduplicationConfig:
    """Alert deduplication configuration"""
    window_seconds: int = 300           # 5 minute window
    max_per_window: int = 3             # Max alerts per window
    group_by: List[str] = None          # Fields to group by

    def __post_init__(self):
        if self.group_by is None:
            self.group_by = ["alert_name", "severity", "source"]


class AlertDeduplicator:
    """Deduplicate and aggregate alerts"""

    def __init__(self, config: DeduplicationConfig, state_store: IStateStore):
        self.config = config
        self.state_store = state_store

    async def should_alert(self, alert: Alert) -> tuple[bool, Optional[str]]:
        """
        Determine if alert should fire or be suppressed.

        Returns:
            (should_fire, reason_if_suppressed)
        """
        # Generate dedup key from grouping fields
        dedup_key = self._generate_key(alert)

        # Check recent alert count
        recent_count = await self._get_recent_count(dedup_key)

        if recent_count >= self.config.max_per_window:
            return (False, f"Suppressed: {recent_count} alerts in last {self.config.window_seconds}s")

        # Record this alert
        await self._record_alert(dedup_key)

        # First occurrence gets special treatment
        if recent_count == 0:
            return (True, None)

        # Subsequent occurrences in window
        if recent_count == self.config.max_per_window - 1:
            # Last allowed alert - add summary
            alert.add_annotation(
                "suppression_notice",
                f"Further alerts will be suppressed for {self.config.window_seconds}s"
            )

        return (True, None)

    def _generate_key(self, alert: Alert) -> str:
        """Generate deduplication key"""
        parts = [str(getattr(alert, field, "")) for field in self.config.group_by]
        return f"alert:dedup:{':'.join(parts)}"

    async def _get_recent_count(self, key: str) -> int:
        """Get count of recent alerts for this key"""
        count = await self.state_store.get(key)
        return int(count) if count else 0

    async def _record_alert(self, key: str) -> None:
        """Record alert occurrence"""
        await self.state_store.increment(key, ttl=self.config.window_seconds)


# Alert aggregation for high-volume alerts
class AlertAggregator:
    """Aggregate multiple similar alerts into summaries"""

    AGGREGATION_WINDOW = 60  # 1 minute

    async def aggregate(self, alerts: List[Alert]) -> List[Alert]:
        """Aggregate similar alerts"""
        grouped = self._group_alerts(alerts)
        aggregated = []

        for key, group in grouped.items():
            if len(group) == 1:
                aggregated.append(group[0])
            else:
                # Create summary alert
                summary = Alert(
                    name=f"{group[0].name}_aggregated",
                    severity=max(a.severity for a in group),
                    message=f"Aggregated {len(group)} similar alerts",
                    annotations={
                        "aggregated_count": len(group),
                        "affected_instances": [a.labels.get("instance") for a in group],
                        "time_range": f"{group[0].timestamp} - {group[-1].timestamp}"
                    }
                )
                aggregated.append(summary)

        return aggregated
```

### 8.4 Escalation Policies

```yaml
# alerting/escalation.yaml

escalation_policies:
  infra_critical:
    description: "Critical infrastructure issues"
    steps:
      - level: 1
        wait: 0m
        targets:
          - on_call_primary_infra
        actions:
          - page
          - phone_call
          - slack_urgent

      - level: 2
        wait: 5m
        targets:
          - on_call_secondary_infra
          - infra_team_lead
        actions:
          - page
          - phone_call

      - level: 3
        wait: 15m
        targets:
          - engineering_manager
          - vp_engineering
        actions:
          - page
          - phone_call
          - email

  app_critical:
    description: "Critical application issues"
    steps:
      - level: 1
        wait: 0m
        targets:
          - on_call_primary_app
        actions:
          - page
          - slack_urgent

      - level: 2
        wait: 10m
        targets:
          - on_call_secondary_app
          - app_team_lead
        actions:
          - page
          - phone_call

      - level: 3
        wait: 20m
        targets:
          - engineering_manager
        actions:
          - page
          - email

  standard:
    description: "Standard high-severity issues"
    steps:
      - level: 1
        wait: 0m
        targets:
          - on_call_primary
        actions:
          - page
          - slack_alerts

      - level: 2
        wait: 15m
        targets:
          - on_call_secondary
        actions:
          - page

      - level: 3
        wait: 30m
        targets:
          - team_lead
        actions:
          - page
          - email


on_call_schedules:
  infra:
    name: "Infrastructure On-Call"
    timezone: "UTC"
    rotation:
      type: weekly
      start_day: monday
      handoff_time: "09:00"
    layers:
      - name: primary
        members: [alice, bob, charlie]
        rotation_type: round_robin
      - name: secondary
        members: [david, emma]
        rotation_type: round_robin

  application:
    name: "Application On-Call"
    timezone: "UTC"
    rotation:
      type: weekly
      start_day: monday
      handoff_time: "09:00"
    layers:
      - name: primary
        members: [frank, grace, henry]
        rotation_type: round_robin
      - name: secondary
        members: [iris, jack]
        rotation_type: round_robin

overrides:
  # Holiday coverage
  - schedule: infra
    start: "2024-12-24T00:00:00Z"
    end: "2024-12-26T23:59:59Z"
    user: alice
    layer: primary
```

### 8.5 Alert Definitions

```yaml
# alerting/alerts.yaml

groups:
  - name: availability
    rules:
      - alert: ServiceDown
        expr: up{job="feedback-arrow"} == 0
        for: 1m
        labels:
          severity: P1
          category: infrastructure
        annotations:
          summary: "Feedback Arrow service is down"
          description: "The main service has been unreachable for more than 1 minute"
          runbook: "runbooks/service_down.md"

      - alert: HighErrorRate
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[5m])) /
            sum(rate(http_requests_total[5m]))
          ) > 0.1
        for: 5m
        labels:
          severity: P2
          category: application
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }} over the last 5 minutes"
          runbook: "runbooks/high_error_rate.md"

  - name: latency
    rules:
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
          ) > 2
        for: 5m
        labels:
          severity: P2
          category: application
        annotations:
          summary: "P95 latency is high"
          description: "P95 latency is {{ $value | humanizeDuration }}"
          runbook: "runbooks/high_latency.md"

  - name: resources
    rules:
      - alert: HighMemoryUsage
        expr: |
          (
            process_resident_memory_bytes /
            container_spec_memory_limit_bytes
          ) > 0.9
        for: 10m
        labels:
          severity: P3
          category: infrastructure
        annotations:
          summary: "High memory usage"
          description: "Memory usage is at {{ $value | humanizePercentage }}"
          runbook: "runbooks/high_memory.md"

      - alert: DiskSpaceLow
        expr: |
          (
            node_filesystem_avail_bytes{mountpoint="/data"} /
            node_filesystem_size_bytes{mountpoint="/data"}
          ) < 0.1
        for: 5m
        labels:
          severity: P2
          category: infrastructure
        annotations:
          summary: "Disk space is critically low"
          description: "Only {{ $value | humanizePercentage }} disk space remaining"
          runbook: "runbooks/disk_space.md"

  - name: llm_providers
    rules:
      - alert: AllProvidersDown
        expr: sum(llm_provider_healthy) == 0
        for: 2m
        labels:
          severity: P1
          category: application
        annotations:
          summary: "All LLM providers are unavailable"
          description: "No LLM providers are responding, analysis will fail"
          runbook: "runbooks/llm_providers.md"

      - alert: ProviderHighLatency
        expr: |
          histogram_quantile(0.95,
            sum(rate(llm_request_duration_seconds_bucket[5m])) by (provider, le)
          ) > 30
        for: 5m
        labels:
          severity: P3
          category: application
        annotations:
          summary: "LLM provider {{ $labels.provider }} has high latency"
          description: "P95 latency is {{ $value | humanizeDuration }}"

  - name: tenant_quotas
    rules:
      - alert: TenantQuotaExceeded
        expr: tenant_quota_usage_ratio > 1
        for: 1m
        labels:
          severity: P3
          category: application
        annotations:
          summary: "Tenant {{ $labels.tenant_id }} exceeded quota"
          description: "Quota type: {{ $labels.quota_type }}, usage: {{ $value | humanizePercentage }}"

      - alert: TenantApproachingQuota
        expr: tenant_quota_usage_ratio > 0.9
        for: 10m
        labels:
          severity: P4
          category: application
        annotations:
          summary: "Tenant {{ $labels.tenant_id }} approaching quota limit"
          description: "Quota type: {{ $labels.quota_type }}, usage: {{ $value | humanizePercentage }}"
```

---

## 9. DASHBOARDS

### 9.1 SLO Dashboard

```yaml
# dashboards/slo.yaml

dashboard:
  title: "Feedback Arrow - SLO Dashboard"
  refresh: 30s
  time_range: 30d

  rows:
    - title: "SLO Summary"
      panels:
        - title: "Availability SLO"
          type: gauge
          query: |
            1 - (
              sum(increase(http_requests_total{status=~"5.."}[30d])) /
              sum(increase(http_requests_total[30d]))
            )
          thresholds:
            - value: 0.999
              color: green
            - value: 0.995
              color: yellow
            - value: 0
              color: red
          target: 0.999

        - title: "Latency SLO (P95 < 500ms)"
          type: gauge
          query: |
            sum(rate(http_request_duration_seconds_bucket{le="0.5"}[30d])) /
            sum(rate(http_request_duration_seconds_count[30d]))
          thresholds:
            - value: 0.95
              color: green
            - value: 0.90
              color: yellow
            - value: 0
              color: red
          target: 0.95

        - title: "Error Rate SLO (< 1%)"
          type: gauge
          query: |
            1 - (
              sum(rate(analysis_errors_total[30d])) /
              sum(rate(analysis_total[30d]))
            )
          thresholds:
            - value: 0.99
              color: green
            - value: 0.95
              color: yellow
            - value: 0
              color: red
          target: 0.99

    - title: "Error Budget"
      panels:
        - title: "Error Budget Remaining"
          type: stat
          query: |
            (
              0.001 - (
                sum(increase(http_requests_total{status=~"5.."}[30d])) /
                sum(increase(http_requests_total[30d]))
              )
            ) / 0.001 * 100
          unit: percent
          colorMode: value

        - title: "Error Budget Burn Rate (1h)"
          type: graph
          query: |
            (
              sum(rate(http_requests_total{status=~"5.."}[1h])) /
              sum(rate(http_requests_total[1h]))
            ) / (0.001 / 720)  # 30-day budget / 720 hours
          yaxis: "burn rate multiple"
          thresholds:
            - value: 1
              color: green
            - value: 3
              color: yellow
            - value: 10
              color: red

    - title: "SLI Trends"
      panels:
        - title: "Availability Over Time"
          type: graph
          query: |
            1 - (
              sum(rate(http_requests_total{status=~"5.."}[1h])) /
              sum(rate(http_requests_total[1h]))
            )
          legend: true

        - title: "Latency Distribution"
          type: heatmap
          query: |
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
          yaxis: latency_bucket

        - title: "Error Rate by Type"
          type: graph
          query: |
            sum(rate(analysis_errors_total[5m])) by (error_type)
          legend: true
```

### 9.2 Business Dashboard

```yaml
# dashboards/business.yaml

dashboard:
  title: "Feedback Arrow - Business Metrics"
  refresh: 1m
  time_range: 7d

  rows:
    - title: "Usage Overview"
      panels:
        - title: "Analyses Today"
          type: stat
          query: |
            sum(increase(analysis_total[24h]))
          sparkline: true

        - title: "Rows Processed Today"
          type: stat
          query: |
            sum(increase(rows_processed_total[24h]))
          unit: short
          sparkline: true

        - title: "Active Tenants"
          type: stat
          query: |
            count(count by (tenant_id) (analysis_total{time > now() - 24h}))
          sparkline: true

        - title: "Token Usage Today"
          type: stat
          query: |
            sum(increase(llm_tokens_total[24h]))
          unit: short
          sparkline: true

    - title: "Usage Trends"
      panels:
        - title: "Analyses Over Time"
          type: graph
          queries:
            - label: "Total"
              query: sum(rate(analysis_total[1h])) * 3600
            - label: "Successful"
              query: sum(rate(analysis_total{status="completed"}[1h])) * 3600
            - label: "Failed"
              query: sum(rate(analysis_total{status="failed"}[1h])) * 3600
          legend: true

        - title: "Rows Processed by Module"
          type: graph
          query: |
            sum(rate(rows_processed_total[1h])) by (module) * 3600
          legend: true

    - title: "Token Consumption"
      panels:
        - title: "Tokens by Provider"
          type: pie
          query: |
            sum(increase(llm_tokens_total[7d])) by (provider)

        - title: "Token Cost Estimate"
          type: graph
          query: |
            sum(rate(llm_tokens_total{type="input"}[1h])) * 0.00001 +
            sum(rate(llm_tokens_total{type="output"}[1h])) * 0.00003
          unit: currencyUSD
          legend: true

    - title: "Top Tenants"
      panels:
        - title: "Top 10 by Rows Processed"
          type: table
          query: |
            topk(10, sum(increase(rows_processed_total[24h])) by (tenant_id))
          columns:
            - tenant_id
            - value

        - title: "Top 10 by Token Usage"
          type: table
          query: |
            topk(10, sum(increase(llm_tokens_total[24h])) by (tenant_id))
          columns:
            - tenant_id
            - value
```

### 9.3 Infrastructure Dashboard

```yaml
# dashboards/infrastructure.yaml

dashboard:
  title: "Feedback Arrow - Infrastructure"
  refresh: 30s
  time_range: 6h

  rows:
    - title: "System Resources"
      panels:
        - title: "CPU Usage"
          type: graph
          query: |
            rate(process_cpu_seconds_total[5m]) * 100
          yaxis: percent
          thresholds:
            - value: 80
              color: yellow
            - value: 95
              color: red

        - title: "Memory Usage"
          type: graph
          queries:
            - label: "Heap Used"
              query: process_resident_memory_bytes
            - label: "Heap Limit"
              query: container_spec_memory_limit_bytes
          unit: bytes

        - title: "Disk I/O"
          type: graph
          queries:
            - label: "Read"
              query: rate(node_disk_read_bytes_total[5m])
            - label: "Write"
              query: rate(node_disk_written_bytes_total[5m])
          unit: bytes/s

        - title: "Network I/O"
          type: graph
          queries:
            - label: "RX"
              query: rate(node_network_receive_bytes_total[5m])
            - label: "TX"
              query: rate(node_network_transmit_bytes_total[5m])
          unit: bytes/s

    - title: "Queue Metrics"
      panels:
        - title: "Queue Depth"
          type: graph
          query: |
            task_queue_size
          thresholds:
            - value: 100
              color: yellow
            - value: 500
              color: red

        - title: "Queue Latency"
          type: graph
          query: |
            histogram_quantile(0.95, sum(rate(task_queue_wait_seconds_bucket[5m])) by (le))
          unit: seconds

        - title: "Tasks in Progress"
          type: graph
          query: |
            tasks_in_progress

        - title: "Task Completion Rate"
          type: graph
          queries:
            - label: "Completed"
              query: rate(tasks_completed_total[5m])
            - label: "Failed"
              query: rate(tasks_failed_total[5m])

    - title: "Cache Performance"
      panels:
        - title: "Cache Hit Rate"
          type: graph
          query: |
            sum(rate(cache_hits_total[5m])) /
            (sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m])))
          yaxis: percent
          thresholds:
            - value: 0.8
              color: green
            - value: 0.5
              color: yellow
            - value: 0
              color: red

        - title: "Cache Size"
          type: graph
          queries:
            - label: "Keys"
              query: cache_keys_total
            - label: "Memory"
              query: cache_memory_bytes

        - title: "Cache Operations"
          type: graph
          queries:
            - label: "Gets"
              query: rate(cache_operations_total{op="get"}[5m])
            - label: "Sets"
              query: rate(cache_operations_total{op="set"}[5m])
            - label: "Deletes"
              query: rate(cache_operations_total{op="delete"}[5m])

    - title: "Database Performance"
      panels:
        - title: "Query Latency"
          type: graph
          query: |
            histogram_quantile(0.95, sum(rate(db_query_duration_seconds_bucket[5m])) by (le))
          unit: seconds

        - title: "Active Connections"
          type: graph
          query: |
            db_connections_active

        - title: "Database Size"
          type: graph
          query: |
            db_size_bytes
          unit: bytes
```

### 9.4 Per-Tenant Dashboard

```yaml
# dashboards/tenant.yaml

dashboard:
  title: "Feedback Arrow - Tenant: $tenant_id"
  refresh: 1m
  time_range: 24h
  variables:
    - name: tenant_id
      type: query
      query: label_values(analysis_total, tenant_id)

  rows:
    - title: "Tenant Overview"
      panels:
        - title: "Tier"
          type: stat
          query: |
            tenant_info{tenant_id="$tenant_id"}
          displayField: tier

        - title: "Analyses Today"
          type: stat
          query: |
            sum(increase(analysis_total{tenant_id="$tenant_id"}[24h]))
          sparkline: true

        - title: "Success Rate"
          type: gauge
          query: |
            sum(rate(analysis_total{tenant_id="$tenant_id", status="completed"}[24h])) /
            sum(rate(analysis_total{tenant_id="$tenant_id"}[24h]))
          thresholds:
            - value: 0.95
              color: green
            - value: 0.80
              color: yellow
            - value: 0
              color: red

    - title: "Quota Usage"
      panels:
        - title: "API Requests (Rate Limit)"
          type: gauge
          query: |
            sum(rate(http_requests_total{tenant_id="$tenant_id"}[1m])) /
            tenant_quota_limit{tenant_id="$tenant_id", quota="rate_limit"}
          format: percentunit

        - title: "Rows Processed (Daily)"
          type: gauge
          query: |
            sum(increase(rows_processed_total{tenant_id="$tenant_id"}[24h])) /
            tenant_quota_limit{tenant_id="$tenant_id", quota="daily_rows"}
          format: percentunit

        - title: "Storage Usage"
          type: gauge
          query: |
            tenant_storage_bytes{tenant_id="$tenant_id"} /
            tenant_quota_limit{tenant_id="$tenant_id", quota="storage"}
          format: percentunit

        - title: "Token Usage (Monthly)"
          type: gauge
          query: |
            sum(increase(llm_tokens_total{tenant_id="$tenant_id"}[30d])) /
            tenant_quota_limit{tenant_id="$tenant_id", quota="monthly_tokens"}
          format: percentunit

    - title: "Usage Trends"
      panels:
        - title: "Analyses Over Time"
          type: graph
          query: |
            sum(rate(analysis_total{tenant_id="$tenant_id"}[1h])) * 3600
          legend: true

        - title: "Latency"
          type: graph
          query: |
            histogram_quantile(0.95,
              sum(rate(http_request_duration_seconds_bucket{tenant_id="$tenant_id"}[5m])) by (le)
            )
          unit: seconds

        - title: "Error Rate"
          type: graph
          query: |
            sum(rate(analysis_total{tenant_id="$tenant_id", status="failed"}[1h])) /
            sum(rate(analysis_total{tenant_id="$tenant_id"}[1h]))
          format: percentunit

    - title: "Cost Attribution"
      panels:
        - title: "Estimated Cost Today"
          type: stat
          query: |
            sum(increase(tenant_cost_usd{tenant_id="$tenant_id"}[24h]))
          unit: currencyUSD

        - title: "Cost Breakdown"
          type: pie
          query: |
            sum(increase(tenant_cost_usd{tenant_id="$tenant_id"}[24h])) by (cost_type)

        - title: "Cost Trend (7 Days)"
          type: graph
          query: |
            sum(increase(tenant_cost_usd{tenant_id="$tenant_id"}[1d]))
          unit: currencyUSD
```

### 9.5 Dashboard Implementation

```python
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

@dataclass
class Panel:
    """Dashboard panel definition"""
    title: str
    panel_type: str  # gauge, graph, stat, table, pie, heatmap
    query: str
    unit: Optional[str] = None
    thresholds: Optional[List[Dict]] = None
    legend: bool = True
    sparkline: bool = False


@dataclass
class Row:
    """Dashboard row containing panels"""
    title: str
    panels: List[Panel]
    height: int = 250


@dataclass
class Dashboard:
    """Complete dashboard definition"""
    title: str
    rows: List[Row]
    refresh_interval: str = "30s"
    time_range: str = "6h"
    variables: Optional[List[Dict]] = None


class DashboardGenerator:
    """Generate Grafana-compatible dashboard JSON"""

    def generate(self, dashboard: Dashboard) -> Dict[str, Any]:
        """Generate Grafana dashboard JSON"""

        panels = []
        y_pos = 0

        for row in dashboard.rows:
            # Row title panel
            panels.append({
                "type": "row",
                "title": row.title,
                "gridPos": {"x": 0, "y": y_pos, "w": 24, "h": 1}
            })
            y_pos += 1

            # Panels in row
            panel_width = 24 // len(row.panels)
            for i, panel in enumerate(row.panels):
                panels.append(self._generate_panel(
                    panel=panel,
                    panel_id=len(panels) + 1,
                    x_pos=i * panel_width,
                    y_pos=y_pos,
                    width=panel_width,
                    height=row.height // 30
                ))

            y_pos += row.height // 30

        return {
            "title": dashboard.title,
            "refresh": dashboard.refresh_interval,
            "time": {"from": f"now-{dashboard.time_range}", "to": "now"},
            "panels": panels,
            "templating": self._generate_variables(dashboard.variables or [])
        }

    def _generate_panel(
        self,
        panel: Panel,
        panel_id: int,
        x_pos: int,
        y_pos: int,
        width: int,
        height: int
    ) -> Dict[str, Any]:
        """Generate single panel JSON"""

        base = {
            "id": panel_id,
            "title": panel.title,
            "type": self._map_panel_type(panel.panel_type),
            "gridPos": {"x": x_pos, "y": y_pos, "w": width, "h": height},
            "targets": [{"expr": panel.query, "refId": "A"}]
        }

        if panel.unit:
            base["fieldConfig"] = {
                "defaults": {"unit": panel.unit}
            }

        if panel.thresholds:
            base["fieldConfig"]["defaults"]["thresholds"] = {
                "mode": "absolute",
                "steps": [
                    {"color": t.get("color", "green"), "value": t.get("value")}
                    for t in panel.thresholds
                ]
            }

        return base

    def _map_panel_type(self, panel_type: str) -> str:
        """Map internal panel type to Grafana panel type"""
        mapping = {
            "gauge": "gauge",
            "graph": "timeseries",
            "stat": "stat",
            "table": "table",
            "pie": "piechart",
            "heatmap": "heatmap"
        }
        return mapping.get(panel_type, "timeseries")
```

---

## SUMMARY

```
OPERATIONS (Extended):
├── Lifecycle Management
│   ├── Startup: Config → Services → Connections → Pipeline → Ready
│   ├── Shutdown: Stop → Drain → Checkpoint → Close → Cleanup
│   └── Cancellation: Signal → Graceful → Force → Save partial
│
├── Error Handling
│   ├── Classification: Transient | Permanent | Degraded | System
│   ├── Retry: Exponential backoff with jitter
│   ├── Circuit Breaker: Closed → Open → Half-Open
│   └── Row-Level: Fail-fast | Continue | Quarantine
│
├── SLOs
│   ├── Availability: 99.9%
│   ├── Latency: P95 < 500ms
│   ├── Error Rate: < 1%
│   └── Throughput: 100 rows/sec
│
├── Runbooks
│   ├── High Error Rate
│   ├── LLM Provider Down
│   └── Database Issues
│
├── Capacity Planning
│   ├── Memory formula
│   ├── Duration formula
│   └── Cost formula
│
├── Disaster Recovery
│   ├── Hourly database backups
│   ├── RPO: 1 hour
│   └── RTO: 30 minutes
│
├── Deployment Procedures [NEW]
│   ├── Blue-Green: Instant switch, < 1 min rollback
│   ├── Canary: Gradual rollout (5% → 100%)
│   ├── Rolling: Sequential replacement
│   ├── Database Migrations: Alembic with expand/contract
│   ├── Rollback: < 5 min target, automatic triggers
│   └── Zero-Downtime Checklist: Pre/during/post steps
│
├── Alerting Policies [NEW]
│   ├── Severity: P1 (immediate) → P4 (next day)
│   ├── Routing: PagerDuty, Slack, Email, Phone
│   ├── Deduplication: 5-min window, max 3 per window
│   ├── Escalation: Level 1 → 2 → 3 with timeouts
│   └── On-Call: Weekly rotation with overrides
│
└── Dashboards [NEW]
    ├── SLO: Availability, latency, error rate, error budget
    ├── Business: Analyses, rows, tokens, costs, top tenants
    ├── Infrastructure: CPU, memory, queues, cache, database
    └── Per-Tenant: Quota usage, trends, cost attribution
```

---

**Document Version:** 1.1.0
**Created:** 2025-12-19
**Updated:** 2025-12-19
**Purpose:** Operational specification for production deployment
