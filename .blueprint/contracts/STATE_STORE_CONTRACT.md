# State Store Specification

**Version:** 1.0.0
**Date:** 2025-12-19
**Purpose:** Define interfaces for stateful operations, persistence, and secret management
**Status:** Specification

---

## DESIGN PRINCIPLES

```
1. COMPUTE NODES ARE STATELESS - All state lives in state stores
2. STATE IS EXPLICIT - No hidden state, all access via interfaces
3. LOCAL-FIRST - File/SQLite defaults, distributed optional
4. TYPED ACCESS - Schema-aware operations where possible
5. OBSERVABLE - All state changes emit telemetry
6. TRANSIENT VS PERSISTENT - Clear distinction in interface
```

---

## 1. IStateStore - TRANSIENT STATE

### 1.1 Purpose

Transient state for cross-batch operations that don't need persistence:
- Duplicate detection (hash sets)
- Rate limiters (token buckets)
- Circuit breakers (failure counts)
- In-flight tracking (batch IDs)

### 1.2 Interface Definition

```python
from typing import Protocol, Optional, List, Dict, Any, Set
from dataclasses import dataclass
from datetime import datetime, timedelta

@dataclass(frozen=True)
class StateValue:
    """Value with metadata"""
    data: bytes
    created_at: datetime
    expires_at: Optional[datetime]
    version: int  # For optimistic concurrency


class IStateStore(Protocol):
    """
    Transient key-value state store.

    Use for: duplicate hashes, rate limiters, circuit breakers
    NOT for: persistent data (use IPersistence instead)
    """

    # Basic operations
    async def get(self, key: str) -> Optional[bytes]:
        """
        Get value by key.

        Returns:
            Value bytes or None if not found/expired
        """
        ...

    async def set(
        self,
        key: str,
        value: bytes,
        ttl: Optional[int] = None
    ) -> None:
        """
        Set value with optional TTL.

        Args:
            key: Unique key
            value: Value bytes
            ttl: Time-to-live in seconds (None = no expiry)
        """
        ...

    async def delete(self, key: str) -> bool:
        """
        Delete key.

        Returns:
            True if key existed and was deleted
        """
        ...

    async def exists(self, key: str) -> bool:
        """Check if key exists"""
        ...

    # Atomic operations
    async def increment(
        self,
        key: str,
        delta: int = 1,
        ttl: Optional[int] = None
    ) -> int:
        """
        Atomic increment (create if not exists).

        Args:
            key: Counter key
            delta: Increment amount (can be negative)
            ttl: TTL for new keys

        Returns:
            New value after increment
        """
        ...

    async def compare_and_swap(
        self,
        key: str,
        expected: bytes,
        new_value: bytes
    ) -> bool:
        """
        Atomic compare-and-swap.

        Returns:
            True if swap succeeded (value matched expected)
        """
        ...

    # Set operations (for duplicate detection)
    async def add_to_set(self, key: str, *values: str) -> int:
        """
        Add values to set.

        Returns:
            Number of new values added (not already in set)
        """
        ...

    async def is_member(self, key: str, value: str) -> bool:
        """Check if value is in set"""
        ...

    async def set_members(self, key: str) -> Set[str]:
        """Get all members of set"""
        ...

    # Batch operations
    async def mget(self, *keys: str) -> Dict[str, Optional[bytes]]:
        """Get multiple keys at once"""
        ...

    async def mset(self, mapping: Dict[str, bytes], ttl: Optional[int] = None) -> None:
        """Set multiple keys at once"""
        ...

    # Lifecycle
    async def clear_namespace(self, namespace: str) -> int:
        """
        Clear all keys with prefix.

        Returns:
            Number of keys deleted
        """
        ...

    async def get_stats(self) -> Dict[str, Any]:
        """Get store statistics (keys, memory, etc.)"""
        ...
```

### 1.3 Implementations

```python
# In-Memory (Default for single-process)
class MemoryStateStore:
    """Thread-safe in-memory state store"""

    def __init__(self, max_size_mb: int = 256):
        self._store: Dict[str, StateValue] = {}
        self._sets: Dict[str, Set[str]] = {}
        self._lock = asyncio.Lock()
        self._max_size = max_size_mb * 1024 * 1024

    async def get(self, key: str) -> Optional[bytes]:
        async with self._lock:
            if key not in self._store:
                return None
            value = self._store[key]
            if value.expires_at and datetime.utcnow() > value.expires_at:
                del self._store[key]
                return None
            return value.data


# Redis/Valkey/DragonflyDB (Distributed)
class RedisStateStore:
    """Redis-compatible state store"""

    def __init__(self, url: str = "redis://localhost:6379"):
        self._client = redis.asyncio.from_url(url)

    async def get(self, key: str) -> Optional[bytes]:
        return await self._client.get(key)

    async def set(self, key: str, value: bytes, ttl: Optional[int] = None) -> None:
        if ttl:
            await self._client.setex(key, ttl, value)
        else:
            await self._client.set(key, value)

    async def increment(self, key: str, delta: int = 1, ttl: Optional[int] = None) -> int:
        value = await self._client.incrby(key, delta)
        if ttl:
            await self._client.expire(key, ttl)
        return value

    async def add_to_set(self, key: str, *values: str) -> int:
        return await self._client.sadd(key, *values)

    async def is_member(self, key: str, value: str) -> bool:
        return await self._client.sismember(key, value)
```

### 1.4 Use Cases

```python
# Duplicate detection
class DuplicateTracker:
    def __init__(self, state: IStateStore, ttl_hours: int = 24):
        self.state = state
        self.ttl = ttl_hours * 3600
        self.set_key = "duplicate_hashes"

    async def is_duplicate(self, content_hash: str) -> bool:
        return await self.state.is_member(self.set_key, content_hash)

    async def mark_seen(self, content_hash: str) -> None:
        await self.state.add_to_set(self.set_key, content_hash)


# Rate limiter
class TokenBucketLimiter:
    def __init__(self, state: IStateStore, rate: int, burst: int):
        self.state = state
        self.rate = rate
        self.burst = burst

    async def acquire(self, key: str, tokens: int = 1) -> bool:
        current = await self.state.increment(f"ratelimit:{key}", tokens)
        if current > self.burst:
            await self.state.increment(f"ratelimit:{key}", -tokens)
            return False
        return True


# Circuit breaker
class CircuitBreaker:
    def __init__(self, state: IStateStore, threshold: int = 5, reset_seconds: int = 60):
        self.state = state
        self.threshold = threshold
        self.reset_seconds = reset_seconds

    async def record_failure(self, service: str) -> None:
        key = f"circuit:{service}:failures"
        await self.state.increment(key, ttl=self.reset_seconds)

    async def is_open(self, service: str) -> bool:
        key = f"circuit:{service}:failures"
        failures = await self.state.get(key)
        return failures and int(failures) >= self.threshold
```

---

## 2. IPersistence - PERSISTENT STATE

### 2.1 Purpose

Persistent structured data that survives restarts:
- Job records (status, metadata, results)
- User accounts and API keys
- Audit logs
- Configuration overrides
- Analysis results cache

### 2.2 Interface Definition

```python
from typing import Protocol, Optional, List, Dict, Any
from dataclasses import dataclass
from datetime import datetime
from enum import Enum

class SortOrder(Enum):
    ASC = "asc"
    DESC = "desc"


@dataclass
class QueryOptions:
    """Query options for find operations"""
    limit: int = 100
    offset: int = 0
    sort_by: Optional[str] = None
    sort_order: SortOrder = SortOrder.DESC
    include_deleted: bool = False


@dataclass
class PersistenceRecord:
    """Generic record with metadata"""
    id: str
    table: str
    data: Dict[str, Any]
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    version: int = 1


class IPersistence(Protocol):
    """
    Persistent structured data storage.

    Use for: jobs, users, audit logs, configuration
    Implementations: DuckDB, SQLite, PostgreSQL
    """

    # CRUD operations
    async def create(
        self,
        table: str,
        data: Dict[str, Any],
        id: Optional[str] = None
    ) -> str:
        """
        Create new record.

        Args:
            table: Table/collection name
            data: Record data
            id: Optional ID (auto-generated if None)

        Returns:
            Record ID
        """
        ...

    async def read(self, table: str, id: str) -> Optional[PersistenceRecord]:
        """
        Read record by ID.

        Returns:
            Record or None if not found
        """
        ...

    async def update(
        self,
        table: str,
        id: str,
        changes: Dict[str, Any],
        version: Optional[int] = None
    ) -> bool:
        """
        Update record.

        Args:
            table: Table name
            id: Record ID
            changes: Fields to update
            version: Expected version (for optimistic concurrency)

        Returns:
            True if updated, False if not found or version mismatch
        """
        ...

    async def delete(self, table: str, id: str, soft: bool = True) -> bool:
        """
        Delete record.

        Args:
            table: Table name
            id: Record ID
            soft: If True, set deleted_at; if False, hard delete

        Returns:
            True if deleted
        """
        ...

    # Query operations
    async def find(
        self,
        table: str,
        query: Dict[str, Any],
        options: Optional[QueryOptions] = None
    ) -> List[PersistenceRecord]:
        """
        Find records matching query.

        Args:
            table: Table name
            query: Filter conditions (field: value or field: {op: value})
            options: Pagination and sorting

        Returns:
            List of matching records
        """
        ...

    async def find_one(
        self,
        table: str,
        query: Dict[str, Any]
    ) -> Optional[PersistenceRecord]:
        """Find first record matching query"""
        ...

    async def count(self, table: str, query: Dict[str, Any]) -> int:
        """Count records matching query"""
        ...

    # Batch operations
    async def create_many(
        self,
        table: str,
        records: List[Dict[str, Any]]
    ) -> List[str]:
        """Create multiple records, returns IDs"""
        ...

    async def update_many(
        self,
        table: str,
        query: Dict[str, Any],
        changes: Dict[str, Any]
    ) -> int:
        """Update matching records, returns count"""
        ...

    async def delete_many(
        self,
        table: str,
        query: Dict[str, Any],
        soft: bool = True
    ) -> int:
        """Delete matching records, returns count"""
        ...

    # Schema management
    async def ensure_table(
        self,
        table: str,
        schema: Dict[str, str]
    ) -> None:
        """
        Ensure table exists with schema.

        Args:
            table: Table name
            schema: Field name to type mapping
        """
        ...

    async def drop_table(self, table: str) -> None:
        """Drop table if exists"""
        ...

    # Transaction support
    async def transaction(self) -> "ITransaction":
        """
        Begin transaction.

        Usage:
            async with persistence.transaction() as tx:
                await tx.create("jobs", {...})
                await tx.update("jobs", id, {...})
                # Auto-commits on exit, rollbacks on exception
        """
        ...


class ITransaction(Protocol):
    """Transaction context"""

    async def create(self, table: str, data: Dict[str, Any]) -> str:
        ...

    async def update(self, table: str, id: str, changes: Dict[str, Any]) -> bool:
        ...

    async def delete(self, table: str, id: str) -> bool:
        ...

    async def commit(self) -> None:
        ...

    async def rollback(self) -> None:
        ...

    async def __aenter__(self) -> "ITransaction":
        ...

    async def __aexit__(self, exc_type, exc_val, exc_tb) -> None:
        ...
```

### 2.3 Implementations

```python
# DuckDB (Default - embedded, fast, Arrow-native)
class DuckDBPersistence:
    """DuckDB-based persistence (Arrow-native, embedded)"""

    def __init__(self, path: str = "data/feedback_arrow.duckdb"):
        self._path = path
        self._conn = duckdb.connect(path)

    async def create(self, table: str, data: Dict[str, Any], id: Optional[str] = None) -> str:
        record_id = id or str(uuid.uuid4())
        now = datetime.utcnow().isoformat()

        columns = ["id", "data", "created_at", "updated_at", "version"]
        values = [record_id, json.dumps(data), now, now, 1]

        self._conn.execute(
            f"INSERT INTO {table} ({','.join(columns)}) VALUES (?, ?, ?, ?, ?)",
            values
        )
        return record_id

    async def find(
        self,
        table: str,
        query: Dict[str, Any],
        options: Optional[QueryOptions] = None
    ) -> List[PersistenceRecord]:
        options = options or QueryOptions()

        where_clauses = []
        params = []

        for field, value in query.items():
            if isinstance(value, dict):
                # Operator query: {"$gt": 5}
                for op, val in value.items():
                    where_clauses.append(f"json_extract(data, '$.{field}') {self._op_map[op]} ?")
                    params.append(val)
            else:
                where_clauses.append(f"json_extract(data, '$.{field}') = ?")
                params.append(value)

        if not options.include_deleted:
            where_clauses.append("deleted_at IS NULL")

        where = " AND ".join(where_clauses) if where_clauses else "1=1"
        order = f"ORDER BY {options.sort_by} {options.sort_order.value}" if options.sort_by else ""
        limit = f"LIMIT {options.limit} OFFSET {options.offset}"

        result = self._conn.execute(
            f"SELECT * FROM {table} WHERE {where} {order} {limit}",
            params
        ).fetchall()

        return [self._row_to_record(row, table) for row in result]


# SQLite (Alternative - more portable)
class SQLitePersistence:
    """SQLite-based persistence"""

    def __init__(self, path: str = "data/feedback_arrow.db"):
        self._path = path
        self._conn = sqlite3.connect(path)


# PostgreSQL (Distributed - for multi-instance)
class PostgresPersistence:
    """PostgreSQL-based persistence (for distributed deployments)"""

    def __init__(self, url: str):
        self._pool = asyncpg.create_pool(url)
```

### 2.4 Standard Tables

```python
# Built-in tables for feedback-arrow

STANDARD_TABLES = {
    "jobs": {
        "id": "TEXT PRIMARY KEY",
        "status": "TEXT",  # pending, running, completed, failed, cancelled
        "input_path": "TEXT",
        "output_path": "TEXT",
        "config": "JSON",
        "progress": "REAL",
        "error": "TEXT",
        "metrics": "JSON",
        "started_at": "TIMESTAMP",
        "completed_at": "TIMESTAMP",
        "created_at": "TIMESTAMP",
        "updated_at": "TIMESTAMP",
    },
    "api_keys": {
        "id": "TEXT PRIMARY KEY",
        "key_hash": "TEXT UNIQUE",
        "name": "TEXT",
        "permissions": "JSON",
        "rate_limit": "INTEGER",
        "expires_at": "TIMESTAMP",
        "last_used_at": "TIMESTAMP",
        "created_at": "TIMESTAMP",
    },
    "audit_logs": {
        "id": "TEXT PRIMARY KEY",
        "action": "TEXT",
        "actor": "TEXT",
        "resource_type": "TEXT",
        "resource_id": "TEXT",
        "details": "JSON",
        "ip_address": "TEXT",
        "created_at": "TIMESTAMP",
    },
    "cache_metadata": {
        "id": "TEXT PRIMARY KEY",
        "cache_key": "TEXT UNIQUE",
        "content_hash": "TEXT",
        "schema_hash": "TEXT",
        "language": "TEXT",
        "provider": "TEXT",
        "tokens_used": "INTEGER",
        "cost_usd": "REAL",
        "created_at": "TIMESTAMP",
        "expires_at": "TIMESTAMP",
    },
}
```

---

## 3. ISecretStore - SECRET MANAGEMENT

### 3.1 Purpose

Secure storage and lifecycle management for secrets:
- LLM API keys (OpenAI, Anthropic, etc.)
- Database credentials
- Encryption keys
- OAuth tokens

### 3.2 Interface Definition

```python
from typing import Protocol, Optional, Dict, Any
from dataclasses import dataclass
from datetime import datetime
from enum import Enum

class SecretType(Enum):
    API_KEY = "api_key"
    DATABASE_URL = "database_url"
    ENCRYPTION_KEY = "encryption_key"
    OAUTH_TOKEN = "oauth_token"
    CERTIFICATE = "certificate"


@dataclass
class SecretMetadata:
    """Secret metadata (without value)"""
    name: str
    secret_type: SecretType
    created_at: datetime
    rotated_at: Optional[datetime]
    expires_at: Optional[datetime]
    version: int
    tags: Dict[str, str]


class ISecretStore(Protocol):
    """
    Secure secret storage and lifecycle management.

    Implementations: Environment, File (encrypted), Vault, AWS Secrets Manager
    """

    async def get_secret(self, name: str) -> str:
        """
        Get secret value.

        Args:
            name: Secret name

        Returns:
            Secret value

        Raises:
            SecretNotFoundError: If secret doesn't exist
            SecretExpiredError: If secret has expired
        """
        ...

    async def set_secret(
        self,
        name: str,
        value: str,
        secret_type: SecretType = SecretType.API_KEY,
        expires_at: Optional[datetime] = None,
        tags: Optional[Dict[str, str]] = None
    ) -> None:
        """
        Set or update secret.

        Args:
            name: Secret name
            value: Secret value (will be encrypted at rest)
            secret_type: Type classification
            expires_at: Optional expiration
            tags: Optional metadata tags
        """
        ...

    async def delete_secret(self, name: str) -> bool:
        """
        Delete secret.

        Returns:
            True if deleted
        """
        ...

    async def rotate_secret(
        self,
        name: str,
        new_value: str,
        grace_period_seconds: int = 3600
    ) -> None:
        """
        Rotate secret with grace period.

        During grace period, both old and new values are valid.
        After grace period, old value is deleted.

        Args:
            name: Secret name
            new_value: New secret value
            grace_period_seconds: Time both values are valid
        """
        ...

    async def list_secrets(
        self,
        prefix: Optional[str] = None,
        secret_type: Optional[SecretType] = None
    ) -> List[SecretMetadata]:
        """
        List secrets (metadata only, not values).

        Args:
            prefix: Filter by name prefix
            secret_type: Filter by type

        Returns:
            List of secret metadata
        """
        ...

    async def get_metadata(self, name: str) -> SecretMetadata:
        """Get secret metadata without value"""
        ...

    async def secret_exists(self, name: str) -> bool:
        """Check if secret exists"""
        ...

    async def get_expiring_secrets(
        self,
        within_days: int = 7
    ) -> List[SecretMetadata]:
        """Get secrets expiring within N days"""
        ...
```

### 3.3 Implementations

```python
# Environment Variables (Default - zero dependencies)
class EnvSecretStore:
    """Environment variable secret store (development/simple deployments)"""

    def __init__(self, prefix: str = "FEEDBACK_ARROW_"):
        self._prefix = prefix
        self._metadata: Dict[str, SecretMetadata] = {}

    async def get_secret(self, name: str) -> str:
        env_name = f"{self._prefix}{name.upper()}"
        value = os.environ.get(env_name)
        if value is None:
            raise SecretNotFoundError(name)
        return value

    async def set_secret(self, name: str, value: str, **kwargs) -> None:
        env_name = f"{self._prefix}{name.upper()}"
        os.environ[env_name] = value
        self._metadata[name] = SecretMetadata(
            name=name,
            secret_type=kwargs.get("secret_type", SecretType.API_KEY),
            created_at=datetime.utcnow(),
            rotated_at=None,
            expires_at=kwargs.get("expires_at"),
            version=1,
            tags=kwargs.get("tags", {})
        )


# Encrypted File (Local, secure at rest)
class EncryptedFileSecretStore:
    """
    File-based secret store with encryption at rest.

    Uses Fernet (AES-128-CBC) symmetric encryption.
    Master key from FEEDBACK_ARROW_MASTER_KEY env var.
    """

    def __init__(self, path: str = "~/.feedback-arrow/secrets.enc"):
        self._path = os.path.expanduser(path)
        self._key = self._get_master_key()
        self._fernet = Fernet(self._key)
        self._secrets: Dict[str, Dict] = self._load()

    def _get_master_key(self) -> bytes:
        key = os.environ.get("FEEDBACK_ARROW_MASTER_KEY")
        if not key:
            raise ConfigurationError("FEEDBACK_ARROW_MASTER_KEY not set")
        return base64.urlsafe_b64decode(key)

    def _load(self) -> Dict:
        if not os.path.exists(self._path):
            return {}
        with open(self._path, "rb") as f:
            encrypted = f.read()
        decrypted = self._fernet.decrypt(encrypted)
        return json.loads(decrypted)

    def _save(self) -> None:
        data = json.dumps(self._secrets).encode()
        encrypted = self._fernet.encrypt(data)
        os.makedirs(os.path.dirname(self._path), exist_ok=True)
        with open(self._path, "wb") as f:
            f.write(encrypted)

    async def get_secret(self, name: str) -> str:
        if name not in self._secrets:
            raise SecretNotFoundError(name)
        secret = self._secrets[name]
        if secret.get("expires_at"):
            expires = datetime.fromisoformat(secret["expires_at"])
            if datetime.utcnow() > expires:
                raise SecretExpiredError(name)
        return secret["value"]


# HashiCorp Vault (Enterprise)
class VaultSecretStore:
    """HashiCorp Vault secret store"""

    def __init__(self, url: str, token: str, mount: str = "secret"):
        self._client = hvac.Client(url=url, token=token)
        self._mount = mount

    async def get_secret(self, name: str) -> str:
        response = self._client.secrets.kv.v2.read_secret_version(
            mount_point=self._mount,
            path=name
        )
        return response["data"]["data"]["value"]


# AWS Secrets Manager
class AWSSecretStore:
    """AWS Secrets Manager secret store"""

    def __init__(self, region: str = "us-east-1"):
        self._client = boto3.client("secretsmanager", region_name=region)

    async def get_secret(self, name: str) -> str:
        response = self._client.get_secret_value(SecretId=name)
        return response["SecretString"]
```

### 3.4 Secret Naming Convention

```yaml
# Standard secret names for feedback-arrow

llm_providers:
  - openai_api_key      # OpenAI API key
  - anthropic_api_key   # Anthropic API key
  - ollama_api_key      # Ollama (if needed)
  - vllm_api_key        # vLLM (if needed)

storage:
  - s3_access_key       # S3/R2 access key
  - s3_secret_key       # S3/R2 secret key
  - gcs_credentials     # GCS JSON credentials
  - gdrive_credentials  # Google Drive OAuth

databases:
  - postgres_url        # PostgreSQL connection URL
  - redis_url           # Redis connection URL

encryption:
  - master_key          # Master encryption key
  - cache_encryption_key # Cache encryption key

external:
  - webhook_secret      # Webhook HMAC secret
  - oauth_client_secret # OAuth client secret
```

---

## 4. INTEGRATION WITH COMPUTE GRAPH

### 4.1 Context Injection

```python
@dataclass
class ExecutionContext:
    """Execution context with state stores"""

    # State stores
    state: IStateStore        # Transient state
    persistence: IPersistence # Persistent data
    secrets: ISecretStore     # Secret management

    # ... other context fields

    async def get_llm_api_key(self, provider: str) -> str:
        """Convenience method for LLM API keys"""
        return await self.secrets.get_secret(f"{provider}_api_key")

    async def track_duplicate(self, content_hash: str) -> bool:
        """Convenience method for duplicate tracking"""
        is_dup = await self.state.is_member("seen_hashes", content_hash)
        if not is_dup:
            await self.state.add_to_set("seen_hashes", content_hash)
        return is_dup
```

### 4.2 Node Usage Examples

```python
class DeduplicateNode(IComputeNode):
    """Deduplicate comments using state store"""

    async def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        duplicates = []
        duplicate_groups = []

        for i, row in enumerate(data.to_pylist()):
            content_hash = hash_content(row["customer_comment"])

            # Check state store for duplicate
            is_dup = await context.state.is_member("seen_hashes", content_hash)

            if is_dup:
                duplicates.append(True)
                # Find original in persistence
                original = await context.persistence.find_one(
                    "seen_comments",
                    {"hash": content_hash}
                )
                duplicate_groups.append(original["id"] if original else None)
            else:
                duplicates.append(False)
                duplicate_groups.append(None)
                await context.state.add_to_set("seen_hashes", content_hash)

        # Add columns
        result = data.append_column("is_duplicate", pa.array(duplicates))
        result = result.append_column("duplicate_of", pa.array(duplicate_groups))

        return NodeResult(output=result, success=True, ...)


class LLMAnalysisNode(IComputeNode):
    """LLM analysis using secrets for API key"""

    async def transform(self, data: pa.Table, context: ExecutionContext) -> NodeResult:
        # Get API key from secret store
        api_key = await context.get_llm_api_key("openai")

        # Check rate limit in state store
        limiter = TokenBucketLimiter(context.state, rate=100, burst=500)
        if not await limiter.acquire("openai"):
            raise RateLimitExceededError("OpenAI rate limit exceeded")

        # Make LLM call
        results = await self.llm_provider.analyze_batch(data, api_key)

        # Track usage in persistence
        await context.persistence.create("llm_usage", {
            "provider": "openai",
            "tokens": results.total_tokens,
            "cost_usd": results.estimated_cost,
            "timestamp": datetime.utcnow().isoformat()
        })

        return NodeResult(output=results.table, success=True, ...)
```

---

## 5. CONFIGURATION

### 5.1 Default Configuration

```yaml
# config/state_stores.yaml

state_store:
  type: memory  # memory | redis | valkey
  config:
    max_size_mb: 256
    default_ttl_seconds: 86400  # 24 hours

  # Redis/Valkey config (if type != memory)
  redis:
    url: "${REDIS_URL:-redis://localhost:6379}"
    db: 0
    key_prefix: "feedback_arrow:"

persistence:
  type: duckdb  # duckdb | sqlite | postgres
  config:
    path: "data/feedback_arrow.duckdb"

  # PostgreSQL config (if type == postgres)
  postgres:
    url: "${DATABASE_URL}"
    pool_size: 10
    ssl: true

secret_store:
  type: env  # env | file | vault | aws
  config:
    prefix: "FEEDBACK_ARROW_"

  # File config (if type == file)
  file:
    path: "~/.feedback-arrow/secrets.enc"

  # Vault config (if type == vault)
  vault:
    url: "${VAULT_ADDR}"
    token: "${VAULT_TOKEN}"
    mount: "secret"

  # AWS config (if type == aws)
  aws:
    region: "${AWS_REGION:-us-east-1}"
```

### 5.2 Factory Functions

```python
def create_state_store(config: Dict[str, Any]) -> IStateStore:
    """Create state store from configuration"""
    store_type = config.get("type", "memory")

    if store_type == "memory":
        return MemoryStateStore(**config.get("config", {}))
    elif store_type in ("redis", "valkey", "dragonfly"):
        return RedisStateStore(url=config["redis"]["url"])
    else:
        raise ConfigurationError(f"Unknown state store type: {store_type}")


def create_persistence(config: Dict[str, Any]) -> IPersistence:
    """Create persistence from configuration"""
    persistence_type = config.get("type", "duckdb")

    if persistence_type == "duckdb":
        return DuckDBPersistence(path=config["config"]["path"])
    elif persistence_type == "sqlite":
        return SQLitePersistence(path=config["config"]["path"])
    elif persistence_type == "postgres":
        return PostgresPersistence(url=config["postgres"]["url"])
    else:
        raise ConfigurationError(f"Unknown persistence type: {persistence_type}")


def create_secret_store(config: Dict[str, Any]) -> ISecretStore:
    """Create secret store from configuration"""
    store_type = config.get("type", "env")

    if store_type == "env":
        return EnvSecretStore(prefix=config["config"]["prefix"])
    elif store_type == "file":
        return EncryptedFileSecretStore(path=config["file"]["path"])
    elif store_type == "vault":
        return VaultSecretStore(**config["vault"])
    elif store_type == "aws":
        return AWSSecretStore(**config["aws"])
    else:
        raise ConfigurationError(f"Unknown secret store type: {store_type}")
```

---

## 6. OBSERVABILITY

### 6.1 Metrics

```python
STATE_STORE_METRICS = {
    "state_store.get.duration_ms": "histogram",
    "state_store.set.duration_ms": "histogram",
    "state_store.hit_rate": "gauge",
    "state_store.keys_count": "gauge",
    "state_store.memory_bytes": "gauge",
}

PERSISTENCE_METRICS = {
    "persistence.query.duration_ms": "histogram",
    "persistence.write.duration_ms": "histogram",
    "persistence.records_count": "counter",
    "persistence.connection_pool.size": "gauge",
}

SECRET_STORE_METRICS = {
    "secrets.access.count": "counter",
    "secrets.rotation.count": "counter",
    "secrets.expiring_soon": "gauge",
}
```

### 6.2 Audit Logging

```python
async def audit_secret_access(
    persistence: IPersistence,
    secret_name: str,
    actor: str,
    action: str = "read"
) -> None:
    """Log secret access for audit trail"""
    await persistence.create("audit_logs", {
        "action": f"secret.{action}",
        "actor": actor,
        "resource_type": "secret",
        "resource_id": secret_name,
        "details": {"timestamp": datetime.utcnow().isoformat()},
        "ip_address": get_client_ip()
    })
```

---

## SUMMARY

```
STATE STORES:
├── IStateStore: Transient key-value (duplicates, rate limits, circuits)
│   ├── MemoryStateStore (default, single-process)
│   └── RedisStateStore (distributed)
│
├── IPersistence: Persistent structured data (jobs, users, audit)
│   ├── DuckDBPersistence (default, Arrow-native)
│   ├── SQLitePersistence (portable)
│   └── PostgresPersistence (distributed)
│
└── ISecretStore: Secret management (API keys, credentials)
    ├── EnvSecretStore (default, zero-deps)
    ├── EncryptedFileSecretStore (local, secure)
    ├── VaultSecretStore (enterprise)
    └── AWSSecretStore (cloud)

INTEGRATION:
- Injected via ExecutionContext
- Nodes access state without coupling to implementations
- Observable by default
- Configurable per environment
```

---

**Document Version:** 1.0.0
**Created:** 2025-12-19
**Purpose:** State management interfaces for compute graph nodes
