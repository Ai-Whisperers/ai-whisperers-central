# LLM Provider Contract - Universal Interface Design

**Version:** 1.0.0
**Date:** 2025-12-15
**Purpose:** Define a minimal, swappable LLM interface that maintains Arrow-first, zero-copy, performance-first principles
**Philosophy:** Local-first, cloud-extensible, no overengineering

---

## DESIGN PRINCIPLES

```
1. THIN ADAPTERS - Adapters translate, they don't think
2. ARROW AT BOUNDARIES - Data enters/exits as Arrow, adapters handle conversion
3. CAPABILITY-BASED - Providers declare what they support, router decides
4. BATCH-NATIVE - Batch is the default, single-item is batch-of-one
5. ASYNC I/O ONLY - All network calls are async, compute stays sync
6. LOCAL-FIRST - Default works offline, cloud is opt-in enhancement
```

---

## 1. CORE INTERFACE

### 1.1 The Universal Contract

```python
from typing import Protocol, List, Dict, Optional, Any
from dataclasses import dataclass
import pyarrow as pa

@dataclass(frozen=True)
class ProviderCapabilities:
    """What this provider can do - immutable, discovered once"""
    provider_id: str
    supports_structured_output: bool  # Native JSON schema enforcement
    supports_batch: bool              # Native batch API (not just loop)
    supports_streaming: bool          # Token streaming
    supports_vision: bool             # Image input
    max_context_tokens: int           # Context window size
    max_output_tokens: int            # Output limit
    tokens_per_second: float          # Throughput estimate (0 = unknown)
    cost_per_1k_input: float          # USD, 0 for local
    cost_per_1k_output: float         # USD, 0 for local
    supports_prompt_caching: bool     # Anthropic/OpenAI prompt cache

@dataclass
class AnalysisRequest:
    """Batch of comments to analyze - Arrow-native"""
    comments: pa.Array              # Arrow string array (zero-copy from table)
    language: str                   # ISO 639-1 code
    analysis_schema: Dict[str, Any] # JSON Schema for structured output

@dataclass
class AnalysisResult:
    """Single comment result - will be assembled into Arrow table"""
    index: int
    raw_response: Dict[str, Any]    # Provider's raw JSON
    tokens_input: int
    tokens_output: int
    latency_ms: int
    provider_used: str

class ILLMProvider(Protocol):
    """
    The universal LLM contract.

    Adapters implement this interface. That's it.
    No inheritance, no abstract base classes, just this Protocol.
    """

    def get_capabilities(self) -> ProviderCapabilities:
        """Return provider capabilities - called once at startup"""
        ...

    async def analyze_batch(
        self,
        request: AnalysisRequest
    ) -> List[AnalysisResult]:
        """
        Analyze a batch of comments.

        This is THE method. Everything else is convenience.
        Adapters convert Arrow array to provider format internally.
        """
        ...

    async def health_check(self) -> bool:
        """Is this provider available right now?"""
        ...
```

### 1.2 Why This Interface Is Minimal

```
REJECTED: analyze_single()
  - Just call analyze_batch() with one item
  - No separate code path to maintain

REJECTED: estimate_cost()
  - Capabilities already has cost_per_1k_*
  - Caller can calculate: len(tokens) * cost_per_1k / 1000

REJECTED: retry logic in interface
  - That's the router's job, not the adapter's
  - Adapters are dumb pipes

REJECTED: streaming in core interface
  - 95% of batch analysis doesn't need streaming
  - Add IStreamingProvider as optional extension if needed

REJECTED: provider-specific options
  - If you need provider-specific features, you're locked in
  - Keep the interface clean, put hacks in adapter internals
```

---

## 2. ADAPTER IMPLEMENTATIONS

### 2.1 Adapter Hierarchy (By API Compatibility)

```
OpenAI-Compatible (thin adapter, ~50 lines each)
├── OllamaAdapter        # Local, most popular
├── VLLMAdapter          # Local, high-performance
├── LlamaCppAdapter      # Local, lightweight
├── LMStudioAdapter      # Local, desktop app
├── LocalAIAdapter       # Local, multi-backend
├── OpenAIAdapter        # Cloud, reference implementation
├── AzureOpenAIAdapter   # Cloud, enterprise
├── GroqAdapter          # Cloud, fast inference
├── TogetherAdapter      # Cloud, many models
├── MistralAdapter       # Cloud, EU-based
└── DeepSeekAdapter      # Cloud, cost-effective

Non-OpenAI (medium adapter, ~100-150 lines each)
├── AnthropicAdapter     # Different message format
├── GeminiAdapter        # Different API structure
└── BedrockAdapter       # AWS wrapper, multi-provider

Direct Loading (thick adapter, ~200 lines each)
├── TransformersAdapter  # HuggingFace, no server
└── MLXAdapter           # Apple Silicon native
```

### 2.2 OpenAI-Compatible Base (The Common Case)

```python
"""
90% of providers are OpenAI-compatible.
This base handles the common case. Specific adapters override only what differs.
"""

import httpx
from typing import List, Dict, Any

class OpenAICompatibleBase:
    """
    Base for all OpenAI-compatible providers.
    Subclasses only override: endpoint, auth, model name.
    """

    def __init__(
        self,
        base_url: str,
        api_key: str = "",  # Empty for local
        model: str = "default",
        timeout: float = 120.0
    ):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.model = model
        self.client = httpx.AsyncClient(timeout=timeout)

    def _build_headers(self) -> Dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return headers

    def _build_request(
        self,
        comments: List[str],
        schema: Dict[str, Any],
        system_prompt: str
    ) -> Dict[str, Any]:
        """Standard OpenAI chat completion request"""
        return {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": self._format_batch(comments)}
            ],
            "response_format": {
                "type": "json_schema",
                "json_schema": {"strict": True, "schema": schema}
            } if schema else None,
            "temperature": 0.1,
        }

    def _format_batch(self, comments: List[str]) -> str:
        """Format comments for batch analysis"""
        return "\n".join(
            f"{i+1}. {comment}"
            for i, comment in enumerate(comments)
        )

    async def _call_api(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Make the actual API call"""
        response = await self.client.post(
            f"{self.base_url}/v1/chat/completions",
            headers=self._build_headers(),
            json=request
        )
        response.raise_for_status()
        return response.json()
```

### 2.3 Concrete Adapters

#### Ollama (Local, Primary)

```python
class OllamaAdapter(OpenAICompatibleBase):
    """
    Ollama adapter - the local-first default.

    Differences from OpenAI:
    - No API key needed
    - Default port 11434
    - Model format: "llama3:8b" not "gpt-4o-mini"
    """

    def __init__(
        self,
        model: str = "llama3:8b",
        host: str = "localhost",
        port: int = 11434
    ):
        super().__init__(
            base_url=f"http://{host}:{port}",
            api_key="",  # No auth for local
            model=model
        )
        self._capabilities = None

    def get_capabilities(self) -> ProviderCapabilities:
        if self._capabilities is None:
            # Discover from Ollama API
            self._capabilities = ProviderCapabilities(
                provider_id=f"ollama/{self.model}",
                supports_structured_output=True,  # Ollama 0.5+ supports this
                supports_batch=False,  # No native batch API
                supports_streaming=True,
                supports_vision="llava" in self.model or "vision" in self.model,
                max_context_tokens=self._get_context_size(),
                max_output_tokens=4096,
                tokens_per_second=0,  # Varies by hardware
                cost_per_1k_input=0.0,  # Free!
                cost_per_1k_output=0.0,
                supports_prompt_caching=False
            )
        return self._capabilities

    def _get_context_size(self) -> int:
        """Query Ollama for model's context size"""
        # Default conservative estimate, actual query in real impl
        return 8192

    async def analyze_batch(
        self,
        request: AnalysisRequest
    ) -> List[AnalysisResult]:
        """
        Ollama doesn't have native batch, so we process sequentially.
        For true parallelism, run multiple Ollama instances.
        """
        results = []
        comments = request.comments.to_pylist()  # Arrow -> Python list (boundary)

        for i, comment in enumerate(comments):
            start_ms = time.monotonic_ns() // 1_000_000

            api_request = self._build_request(
                comments=[comment],  # Single item
                schema=request.analysis_schema,
                system_prompt=self._get_system_prompt(request.language)
            )

            response = await self._call_api(api_request)

            results.append(AnalysisResult(
                index=i,
                raw_response=self._parse_response(response),
                tokens_input=response["usage"]["prompt_tokens"],
                tokens_output=response["usage"]["completion_tokens"],
                latency_ms=int(time.monotonic_ns() // 1_000_000 - start_ms),
                provider_used=self.get_capabilities().provider_id
            ))

        return results

    async def health_check(self) -> bool:
        try:
            response = await self.client.get(f"{self.base_url}/api/tags")
            return response.status_code == 200
        except:
            return False
```

#### vLLM (Local, High-Performance)

```python
class VLLMAdapter(OpenAICompatibleBase):
    """
    vLLM adapter - high-throughput local inference.

    Differences from base:
    - Supports true batching via continuous batching
    - Higher throughput than Ollama
    - Requires more VRAM
    """

    def __init__(
        self,
        model: str = "meta-llama/Llama-3-8B-Instruct",
        host: str = "localhost",
        port: int = 8000
    ):
        super().__init__(
            base_url=f"http://{host}:{port}",
            api_key="",
            model=model
        )

    def get_capabilities(self) -> ProviderCapabilities:
        return ProviderCapabilities(
            provider_id=f"vllm/{self.model}",
            supports_structured_output=True,  # vLLM supports guided decoding
            supports_batch=True,  # Continuous batching!
            supports_streaming=True,
            supports_vision=False,  # Depends on model
            max_context_tokens=8192,
            max_output_tokens=4096,
            tokens_per_second=0,  # Hardware dependent
            cost_per_1k_input=0.0,
            cost_per_1k_output=0.0,
            supports_prompt_caching=True  # vLLM has prefix caching
        )

    async def analyze_batch(
        self,
        request: AnalysisRequest
    ) -> List[AnalysisResult]:
        """
        vLLM handles batching internally via continuous batching.
        We can send the full batch in one request.
        """
        comments = request.comments.to_pylist()
        start_ms = time.monotonic_ns() // 1_000_000

        # vLLM can handle the full batch
        api_request = self._build_request(
            comments=comments,
            schema=request.analysis_schema,
            system_prompt=self._get_system_prompt(request.language)
        )

        response = await self._call_api(api_request)
        elapsed_ms = int(time.monotonic_ns() // 1_000_000 - start_ms)

        # Parse batch response into individual results
        parsed = self._parse_batch_response(response, len(comments))

        return [
            AnalysisResult(
                index=i,
                raw_response=parsed[i],
                tokens_input=response["usage"]["prompt_tokens"] // len(comments),
                tokens_output=response["usage"]["completion_tokens"] // len(comments),
                latency_ms=elapsed_ms,
                provider_used=self.get_capabilities().provider_id
            )
            for i in range(len(comments))
        ]
```

#### OpenAI (Cloud, Reference)

```python
class OpenAIAdapter(OpenAICompatibleBase):
    """
    OpenAI adapter - the cloud reference implementation.

    This is what everyone else copies, so it's the simplest.
    """

    def __init__(
        self,
        api_key: str,
        model: str = "gpt-4o-mini"
    ):
        super().__init__(
            base_url="https://api.openai.com",
            api_key=api_key,
            model=model
        )

    def get_capabilities(self) -> ProviderCapabilities:
        # Model-specific capabilities
        caps = {
            "gpt-4o-mini": {
                "max_context": 128000,
                "cost_in": 0.00015,
                "cost_out": 0.0006,
            },
            "gpt-4o": {
                "max_context": 128000,
                "cost_in": 0.0025,
                "cost_out": 0.01,
            },
        }
        model_caps = caps.get(self.model, caps["gpt-4o-mini"])

        return ProviderCapabilities(
            provider_id=f"openai/{self.model}",
            supports_structured_output=True,
            supports_batch=True,  # Batch API available
            supports_streaming=True,
            supports_vision="vision" in self.model or "gpt-4o" in self.model,
            max_context_tokens=model_caps["max_context"],
            max_output_tokens=16384,
            tokens_per_second=100,  # Typical
            cost_per_1k_input=model_caps["cost_in"],
            cost_per_1k_output=model_caps["cost_out"],
            supports_prompt_caching=True
        )
```

#### Anthropic (Cloud, Different Format)

```python
class AnthropicAdapter:
    """
    Anthropic adapter - requires format translation.

    Key differences:
    - Messages API, not chat completions
    - System prompt is separate parameter, not a message
    - Different response structure
    """

    def __init__(
        self,
        api_key: str,
        model: str = "claude-3-haiku-20240307"
    ):
        self.api_key = api_key
        self.model = model
        self.client = httpx.AsyncClient(timeout=120.0)
        self.base_url = "https://api.anthropic.com"

    def get_capabilities(self) -> ProviderCapabilities:
        caps = {
            "claude-3-haiku-20240307": {
                "max_context": 200000,
                "cost_in": 0.00025,
                "cost_out": 0.00125,
            },
            "claude-3-5-sonnet-20241022": {
                "max_context": 200000,
                "cost_in": 0.003,
                "cost_out": 0.015,
            },
        }
        model_caps = caps.get(self.model, caps["claude-3-haiku-20240307"])

        return ProviderCapabilities(
            provider_id=f"anthropic/{self.model}",
            supports_structured_output=True,  # Tool use for structured
            supports_batch=True,
            supports_streaming=True,
            supports_vision=True,
            max_context_tokens=model_caps["max_context"],
            max_output_tokens=8192,
            tokens_per_second=80,
            cost_per_1k_input=model_caps["cost_in"],
            cost_per_1k_output=model_caps["cost_out"],
            supports_prompt_caching=True  # Anthropic has prompt caching
        )

    async def analyze_batch(
        self,
        request: AnalysisRequest
    ) -> List[AnalysisResult]:
        """Translate to Anthropic's format"""
        comments = request.comments.to_pylist()
        start_ms = time.monotonic_ns() // 1_000_000

        # Anthropic format (different from OpenAI)
        api_request = {
            "model": self.model,
            "max_tokens": 4096,
            "system": self._get_system_prompt(request.language),  # Separate!
            "messages": [
                {"role": "user", "content": self._format_batch(comments)}
            ],
            # Use tool_use for structured output
            "tools": [{
                "name": "analysis_result",
                "description": "Structured analysis output",
                "input_schema": request.analysis_schema
            }],
            "tool_choice": {"type": "tool", "name": "analysis_result"}
        }

        response = await self.client.post(
            f"{self.base_url}/v1/messages",
            headers={
                "x-api-key": self.api_key,
                "anthropic-version": "2023-06-01",
                "Content-Type": "application/json"
            },
            json=api_request
        )
        response.raise_for_status()
        data = response.json()

        elapsed_ms = int(time.monotonic_ns() // 1_000_000 - start_ms)

        # Extract tool use result
        tool_result = self._extract_tool_result(data)
        parsed = self._parse_batch_response(tool_result, len(comments))

        return [
            AnalysisResult(
                index=i,
                raw_response=parsed[i],
                tokens_input=data["usage"]["input_tokens"] // len(comments),
                tokens_output=data["usage"]["output_tokens"] // len(comments),
                latency_ms=elapsed_ms,
                provider_used=self.get_capabilities().provider_id
            )
            for i in range(len(comments))
        ]
```

---

## 3. PROVIDER ROUTER

### 3.1 Routing Strategy

```python
from enum import Enum
from typing import Optional

class RoutingStrategy(Enum):
    LOCAL_FIRST = "local_first"      # Try local, fallback to cloud
    COST_OPTIMIZED = "cost"          # Cheapest available
    LATENCY_OPTIMIZED = "latency"    # Fastest available
    QUALITY_OPTIMIZED = "quality"    # Best model available
    FAILOVER = "failover"            # Strict priority chain

@dataclass
class RoutingConfig:
    strategy: RoutingStrategy = RoutingStrategy.LOCAL_FIRST
    local_providers: List[str] = None      # ["ollama", "vllm"]
    cloud_providers: List[str] = None      # ["openai", "anthropic"]
    fallback_chain: List[str] = None       # Explicit priority order
    max_cost_per_1k: float = 0.01          # Cost ceiling
    max_latency_ms: int = 5000             # Latency ceiling
    prefer_structured_output: bool = True  # Prefer providers with native JSON


class LLMRouter:
    """
    Routes requests to appropriate provider based on strategy.

    NOT a load balancer - this is intelligent routing based on:
    - Provider capabilities
    - Request requirements
    - Cost/latency constraints
    - Provider health
    """

    def __init__(
        self,
        providers: Dict[str, ILLMProvider],
        config: RoutingConfig
    ):
        self.providers = providers
        self.config = config
        self._health_cache: Dict[str, bool] = {}

    async def get_provider(
        self,
        request: AnalysisRequest,
        required_capabilities: Optional[List[str]] = None
    ) -> ILLMProvider:
        """Select best provider for this request"""

        candidates = await self._get_healthy_providers()

        if required_capabilities:
            candidates = self._filter_by_capabilities(
                candidates,
                required_capabilities
            )

        if not candidates:
            raise NoProviderAvailableError("No healthy providers match requirements")

        if self.config.strategy == RoutingStrategy.LOCAL_FIRST:
            return self._route_local_first(candidates)
        elif self.config.strategy == RoutingStrategy.COST_OPTIMIZED:
            return self._route_by_cost(candidates)
        elif self.config.strategy == RoutingStrategy.LATENCY_OPTIMIZED:
            return self._route_by_latency(candidates)
        elif self.config.strategy == RoutingStrategy.QUALITY_OPTIMIZED:
            return self._route_by_quality(candidates)
        else:  # FAILOVER
            return self._route_failover(candidates)

    def _route_local_first(
        self,
        candidates: List[ILLMProvider]
    ) -> ILLMProvider:
        """Prefer local providers, fall back to cloud"""

        # Try local first
        for provider_id in (self.config.local_providers or []):
            if provider_id in candidates:
                return candidates[provider_id]

        # Fall back to cloud
        for provider_id in (self.config.cloud_providers or []):
            if provider_id in candidates:
                return candidates[provider_id]

        # Last resort: first available
        return list(candidates.values())[0]

    def _route_by_cost(
        self,
        candidates: List[ILLMProvider]
    ) -> ILLMProvider:
        """Select cheapest provider under cost ceiling"""
        return min(
            candidates.values(),
            key=lambda p: (
                p.get_capabilities().cost_per_1k_input +
                p.get_capabilities().cost_per_1k_output
            )
        )
```

### 3.2 Batch Orchestration with Arrow

```python
class BatchOrchestrator:
    """
    Orchestrates batch analysis with Arrow-native data flow.

    Data flow:
    1. Receive Arrow Table with comments column
    2. Extract comments as Arrow Array (zero-copy)
    3. Route to provider
    4. Collect results
    5. Build result columns as Arrow Arrays
    6. Return Arrow Table (zero-copy append to original)
    """

    def __init__(
        self,
        router: LLMRouter,
        cache: Optional[ICache] = None
    ):
        self.router = router
        self.cache = cache

    async def analyze_table(
        self,
        table: pa.Table,
        comment_column: str,
        language: str,
        schema: Dict[str, Any]
    ) -> pa.Table:
        """
        Analyze comments in Arrow Table, return enriched table.

        Zero-copy where possible:
        - Input column extracted as Arrow Array (zero-copy)
        - Results built as Arrow Arrays
        - Output table created with zero-copy column append
        """

        # Extract comments (zero-copy view)
        comments_array = table.column(comment_column)

        # Check cache for existing results
        if self.cache:
            cached, uncached_indices = await self._check_cache(
                comments_array,
                language
            )
        else:
            cached = {}
            uncached_indices = list(range(len(comments_array)))

        # Analyze uncached comments
        if uncached_indices:
            uncached_comments = pa.array([
                comments_array[i].as_py()
                for i in uncached_indices
            ])

            request = AnalysisRequest(
                comments=uncached_comments,
                language=language,
                analysis_schema=schema
            )

            provider = await self.router.get_provider(request)
            results = await provider.analyze_batch(request)

            # Cache results
            if self.cache:
                await self._store_cache(uncached_comments, results, language)

            # Merge cached and new results
            all_results = self._merge_results(cached, results, uncached_indices)
        else:
            all_results = cached

        # Build Arrow arrays from results (this is the boundary)
        result_columns = self._build_arrow_columns(all_results)

        # Append columns to table (zero-copy)
        enriched = table
        for name, array in result_columns.items():
            enriched = enriched.append_column(name, array)

        return enriched

    def _build_arrow_columns(
        self,
        results: List[AnalysisResult]
    ) -> Dict[str, pa.Array]:
        """Convert results to Arrow arrays"""

        # Pre-allocate lists for efficiency
        n = len(results)
        sentiments = [None] * n
        emotions = [None] * n
        churn_risks = [None] * n
        # ... etc

        for r in results:
            i = r.index
            data = r.raw_response
            sentiments[i] = data.get("sentiment_score")
            emotions[i] = data.get("emotion")
            churn_risks[i] = data.get("churn_risk")

        return {
            "sentiment_score": pa.array(sentiments, type=pa.float64()),
            "emotion": pa.array(emotions, type=pa.utf8()),
            "churn_risk": pa.array(churn_risks, type=pa.int32()),
            # ... etc
        }
```

---

## 4. CONFIGURATION

### 4.1 Environment-Based Configuration

```python
# Default configuration - local first, cloud fallback
LLM_CONFIG = {
    # Routing
    "routing": {
        "strategy": "local_first",
        "local_providers": ["ollama", "vllm", "llamacpp"],
        "cloud_providers": ["openai", "anthropic"],
        "fallback_chain": ["ollama", "openai", "anthropic"],
    },

    # Provider configurations
    "providers": {
        "ollama": {
            "enabled": True,
            "host": "${OLLAMA_HOST:-localhost}",
            "port": "${OLLAMA_PORT:-11434}",
            "model": "${OLLAMA_MODEL:-llama3:8b}",
            "priority": 1,
        },
        "vllm": {
            "enabled": "${VLLM_ENABLED:-false}",
            "host": "${VLLM_HOST:-localhost}",
            "port": "${VLLM_PORT:-8000}",
            "model": "${VLLM_MODEL:-meta-llama/Llama-3-8B-Instruct}",
            "priority": 2,
        },
        "openai": {
            "enabled": "${OPENAI_ENABLED:-false}",
            "api_key": "${OPENAI_API_KEY}",
            "model": "${OPENAI_MODEL:-gpt-4o-mini}",
            "priority": 10,
            "max_daily_cost": 10.0,
        },
        "anthropic": {
            "enabled": "${ANTHROPIC_ENABLED:-false}",
            "api_key": "${ANTHROPIC_API_KEY}",
            "model": "${ANTHROPIC_MODEL:-claude-3-haiku-20240307}",
            "priority": 11,
            "max_daily_cost": 10.0,
        },
    },

    # Performance tuning
    "performance": {
        "batch_size": 50,                    # Comments per batch
        "max_concurrent_batches": 4,         # Parallel batches
        "timeout_seconds": 120,              # Per-batch timeout
        "retry_attempts": 3,                 # Retries on failure
        "retry_backoff_factor": 2,           # Exponential backoff
    },

    # Cost controls
    "cost": {
        "max_cost_per_request": 0.10,        # USD
        "max_daily_cost": 50.0,              # USD
        "prefer_free_providers": True,       # Always try local first
    },
}
```

### 4.2 Minimal Startup (Just Works)

```python
# Simplest possible setup - just Ollama
from feedback_analyzer import create_analyzer

# This works with just Ollama running locally
analyzer = create_analyzer()  # Auto-discovers Ollama on localhost:11434
results = await analyzer.analyze_file("feedback.csv")

# Add cloud fallback
analyzer = create_analyzer(
    openai_key="sk-...",  # Now has fallback
)

# Full configuration
analyzer = create_analyzer(
    providers={
        "ollama": {"model": "llama3:70b"},  # Bigger local model
        "openai": {"api_key": "sk-...", "model": "gpt-4o"},  # Premium cloud
    },
    routing="local_first"
)
```

---

## 5. ADAPTER SWAPPABILITY GUARANTEES

### 5.1 What Adapters MUST Do

```
1. Implement ILLMProvider Protocol exactly
2. Accept Arrow Array in AnalysisRequest
3. Return List[AnalysisResult] with required fields
4. Handle their own retries internally (optional)
5. Translate to/from provider-specific formats internally
6. Report accurate capabilities
```

### 5.2 What Adapters MUST NOT Do

```
1. Leak provider-specific types to callers
2. Require provider-specific configuration in AnalysisRequest
3. Modify the input Arrow Array
4. Cache results (router/orchestrator handles this)
5. Make routing decisions (router handles this)
6. Handle business logic (domain layer handles this)
```

### 5.3 Testing Swappability

```python
# Every adapter must pass this test
async def test_adapter_contract(adapter: ILLMProvider):
    """Verify adapter implements contract correctly"""

    # 1. Capabilities are valid
    caps = adapter.get_capabilities()
    assert caps.provider_id is not None
    assert caps.max_context_tokens > 0
    assert caps.cost_per_1k_input >= 0

    # 2. Health check works
    is_healthy = await adapter.health_check()
    assert isinstance(is_healthy, bool)

    # 3. Can analyze a batch
    test_comments = pa.array(["Test comment one", "Test comment two"])
    request = AnalysisRequest(
        comments=test_comments,
        language="en",
        analysis_schema=MINIMAL_SCHEMA
    )

    results = await adapter.analyze_batch(request)

    assert len(results) == 2
    for r in results:
        assert isinstance(r, AnalysisResult)
        assert r.index in [0, 1]
        assert isinstance(r.raw_response, dict)
        assert r.tokens_input >= 0
        assert r.tokens_output >= 0
        assert r.provider_used == caps.provider_id
```

---

## 6. PERFORMANCE CONSIDERATIONS

### 6.1 Arrow Integration Points

```
ZERO-COPY BOUNDARIES:
✓ Table column extraction (comments_array = table.column("comment"))
✓ Result column append (table.append_column("sentiment", array))
✓ Array slicing for batches (comments[start:end])

COPY BOUNDARIES (unavoidable):
✗ Arrow Array -> Python list for API call (comments.to_pylist())
✗ API response -> Python dict (json.loads())
✗ Python list -> Arrow Array for results (pa.array(results))

OPTIMIZATION:
- Minimize to_pylist() calls - do once per batch, not per item
- Build result arrays in one pass, not incrementally
- Use Arrow's native JSON parsing if available
```

### 6.2 Batch Size Tuning

```python
BATCH_SIZE_GUIDELINES = {
    # Local models (memory-bound)
    "ollama_7b": 10,       # ~2GB VRAM per batch
    "ollama_13b": 5,       # ~4GB VRAM per batch
    "ollama_70b": 2,       # ~20GB VRAM per batch
    "vllm": 50,            # Continuous batching handles this

    # Cloud models (rate-limit-bound)
    "openai": 50,          # Stay under TPM limits
    "anthropic": 30,       # More conservative

    # Hybrid strategy
    "auto": "memory_gb / 4 for local, 50 for cloud"
}
```

### 6.3 Latency Optimization

```
LOCAL OPTIMIZATION:
1. Keep model loaded (Ollama does this automatically)
2. Use GPU if available (vLLM auto-detects)
3. Enable KV cache (most frameworks do this)
4. Consider quantization (GGUF Q4 vs Q8 tradeoff)

CLOUD OPTIMIZATION:
1. Enable prompt caching (OpenAI/Anthropic)
2. Reuse connections (httpx connection pooling)
3. Batch requests (fewer round trips)
4. Use regional endpoints (lower latency)
```

---

## 7. FUTURE EXTENSIONS

### 7.1 Optional Interfaces (Add When Needed)

```python
# Streaming (for real-time UI feedback)
class IStreamingProvider(Protocol):
    async def analyze_stream(
        self,
        request: AnalysisRequest
    ) -> AsyncIterator[PartialResult]:
        ...

# Vision (for image-based feedback)
class IVisionProvider(Protocol):
    async def analyze_with_image(
        self,
        request: VisionRequest
    ) -> List[AnalysisResult]:
        ...

# Fine-tuning (for custom models)
class IFineTunableProvider(Protocol):
    async def fine_tune(
        self,
        training_data: pa.Table,
        config: FineTuneConfig
    ) -> str:  # Returns model ID
        ...
```

### 7.2 Provider Additions (Easy to Add)

```
When adding a new provider:

1. Check if OpenAI-compatible
   YES → Extend OpenAICompatibleBase, override only differences
   NO  → Implement ILLMProvider directly

2. Implement get_capabilities() with accurate values

3. Implement analyze_batch() with format translation

4. Add to configuration schema

5. Run test_adapter_contract()

Done. No changes to router, orchestrator, or domain logic.
```

---

## SUMMARY

```
CORE INTERFACE:
- ILLMProvider with 3 methods: get_capabilities, analyze_batch, health_check
- AnalysisRequest with Arrow Array input
- AnalysisResult with structured output

ADAPTERS:
- OpenAI-compatible base handles 90% of providers
- Anthropic/Gemini need format translation
- Direct loading (Transformers/MLX) for serverless

ROUTING:
- Strategy-based: local_first, cost, latency, quality, failover
- Capability filtering
- Health-aware

PERFORMANCE:
- Arrow at boundaries (zero-copy where possible)
- Batch-native (single is batch of one)
- Async I/O only

SWAPPABILITY:
- Protocol-based (no inheritance required)
- Adapters are dumb pipes
- Business logic stays in domain layer
```

---

**Document Version:** 1.0.0
**Generated:** 2025-12-15
**Principle:** Local-first, cloud-extensible, Arrow-native, no overengineering
