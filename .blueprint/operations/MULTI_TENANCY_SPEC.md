# Multi-Tenancy Specification

**Purpose:** Tenant isolation, quotas, billing, and data lifecycle for SaaS deployment
**Status:** Authoritative
**Date:** 2025-12-19

---

## 1. Tenant Model

### 1.1 Tenant Hierarchy

```
Organization (billing entity)
    └── Workspace (isolation boundary)
            └── Project (logical grouping)
                    └── Analysis (job)

Example:
  Acme Corp (org_acme123)
      └── Customer Success (ws_custsuccess)
              └── Q4 Survey (proj_q4survey)
                      └── Analysis #1 (ana_abc123)
```

### 1.2 Entity Schemas

```python
@dataclass
class Organization:
    """Billing entity - one per paying customer"""
    org_id: str              # org_{ulid}
    name: str
    billing_email: str
    tier: Tier               # free | pro | enterprise
    status: OrgStatus        # active | suspended | deleted
    created_at: datetime
    metadata: Dict

@dataclass
class Workspace:
    """Isolation boundary - data cannot cross workspaces"""
    workspace_id: str        # ws_{ulid}
    org_id: str              # Parent organization
    name: str
    status: WorkspaceStatus  # active | archived
    settings: WorkspaceSettings
    created_at: datetime

@dataclass
class Project:
    """Logical grouping for related analyses"""
    project_id: str          # proj_{ulid}
    workspace_id: str        # Parent workspace
    name: str
    language: str            # Default language pack
    settings: ProjectSettings
    created_at: datetime

@dataclass
class TenantContext:
    """Runtime context for request processing"""
    org_id: str
    workspace_id: str
    project_id: Optional[str]
    user_id: Optional[str]
    api_key_id: Optional[str]
    tier: Tier
    quotas: QuotaLimits
```

### 1.3 ID Generation

**Format:** `{prefix}_{ulid}`

```python
import ulid

ENTITY_PREFIXES = {
    "organization": "org",
    "workspace": "ws",
    "project": "proj",
    "analysis": "ana",
    "user": "usr",
    "api_key": "key",
}

def generate_id(entity_type: str) -> str:
    prefix = ENTITY_PREFIXES[entity_type]
    return f"{prefix}_{ulid.new().str.lower()}"

# Examples:
# org_01hqx5k8n7gm4r2p3j6c9b0a
# ws_01hqx5k8n7gm4r2p3j6c9b0b
# ana_01hqx5k8n7gm4r2p3j6c9b0c
```

**Properties:**
- Lexicographically sortable (time-ordered)
- URL-safe characters
- 26 characters total (3 prefix + 1 underscore + 22 ULID)

### 1.4 Tenant States

```python
class OrgStatus(Enum):
    ACTIVE = "active"           # Normal operation
    TRIAL = "trial"             # Trial period (14 days)
    SUSPENDED = "suspended"     # Payment failed, read-only
    PENDING_DELETE = "pending_delete"  # Deletion requested
    DELETED = "deleted"         # Soft deleted, data retained 30 days

class WorkspaceStatus(Enum):
    ACTIVE = "active"
    ARCHIVED = "archived"       # Read-only, no new analyses

# State transitions
VALID_TRANSITIONS = {
    OrgStatus.TRIAL: [OrgStatus.ACTIVE, OrgStatus.SUSPENDED],
    OrgStatus.ACTIVE: [OrgStatus.SUSPENDED, OrgStatus.PENDING_DELETE],
    OrgStatus.SUSPENDED: [OrgStatus.ACTIVE, OrgStatus.PENDING_DELETE],
    OrgStatus.PENDING_DELETE: [OrgStatus.DELETED, OrgStatus.ACTIVE],
    OrgStatus.DELETED: [],  # Terminal state
}
```

---

## 2. Isolation

### 2.1 Data Isolation

**Principle:** Data from one workspace MUST NOT be accessible from another.

**Storage Key Namespacing:**
```python
def storage_key(workspace_id: str, resource_type: str, resource_id: str) -> str:
    """All storage keys include workspace_id prefix"""
    return f"{workspace_id}/{resource_type}/{resource_id}"

# Examples:
# ws_abc123/analyses/ana_def456/input.parquet
# ws_abc123/analyses/ana_def456/output.parquet
# ws_abc123/cache/sentiment/hash_xyz789
```

**Database Isolation:**
```sql
-- Every table includes workspace_id
CREATE TABLE analyses (
    analysis_id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,  -- Always present
    project_id TEXT,
    status TEXT,
    created_at TIMESTAMP,
    -- ...
    CONSTRAINT fk_workspace FOREIGN KEY (workspace_id) REFERENCES workspaces(workspace_id)
);

-- Every query includes workspace filter
SELECT * FROM analyses
WHERE workspace_id = :workspace_id  -- ALWAYS filter by workspace
  AND analysis_id = :analysis_id;

-- Row-level security (PostgreSQL)
CREATE POLICY workspace_isolation ON analyses
    USING (workspace_id = current_setting('app.workspace_id'));
```

**Cache Isolation:**
```python
class TenantAwareCache(ICache):
    """Cache keys automatically namespaced by workspace"""

    def __init__(self, backend: ICache, context: TenantContext):
        self.backend = backend
        self.workspace_id = context.workspace_id

    def _key(self, key: str) -> str:
        return f"{self.workspace_id}:{key}"

    async def get(self, key: str) -> Optional[bytes]:
        return await self.backend.get(self._key(key))

    async def set(self, key: str, value: bytes, ttl: Optional[int] = None) -> None:
        await self.backend.set(self._key(key), value, ttl)
```

### 2.2 Compute Isolation

**Job Queue Separation by Tier:**

```python
TIER_QUEUES = {
    Tier.FREE: "jobs:free",           # Shared, low priority
    Tier.PRO: "jobs:pro",             # Shared, normal priority
    Tier.ENTERPRISE: "jobs:ent:{ws}", # Dedicated per workspace
}

def get_queue(context: TenantContext) -> str:
    if context.tier == Tier.ENTERPRISE:
        return f"jobs:ent:{context.workspace_id}"
    return TIER_QUEUES[context.tier]
```

**Worker Allocation:**
```
Free Tier:      Shared worker pool, max 2 concurrent per workspace
Pro Tier:       Shared worker pool, max 10 concurrent per workspace
Enterprise:     Dedicated workers, configurable concurrency
```

**Resource Limits per Job:**
```python
@dataclass
class JobResourceLimits:
    max_memory_mb: int
    max_cpu_seconds: int
    max_duration_seconds: int
    max_rows: int

TIER_JOB_LIMITS = {
    Tier.FREE: JobResourceLimits(
        max_memory_mb=512,
        max_cpu_seconds=60,
        max_duration_seconds=300,
        max_rows=1000
    ),
    Tier.PRO: JobResourceLimits(
        max_memory_mb=2048,
        max_cpu_seconds=600,
        max_duration_seconds=1800,
        max_rows=50000
    ),
    Tier.ENTERPRISE: JobResourceLimits(
        max_memory_mb=8192,
        max_cpu_seconds=3600,
        max_duration_seconds=7200,
        max_rows=500000
    ),
}
```

### 2.3 Network Isolation

**API Rate Limiting by Tier:**
```python
TIER_RATE_LIMITS = {
    Tier.FREE: RateLimit(requests_per_minute=10, burst=20),
    Tier.PRO: RateLimit(requests_per_minute=100, burst=200),
    Tier.ENTERPRISE: RateLimit(requests_per_minute=1000, burst=2000),
}
```

**IP Allowlisting (Enterprise):**
```python
@dataclass
class NetworkPolicy:
    workspace_id: str
    allowed_ips: List[str]      # CIDR notation
    allowed_countries: List[str] # ISO 3166-1 alpha-2
    enabled: bool

# Enforcement
async def check_network_policy(ctx: TenantContext, request: Request) -> bool:
    if ctx.tier != Tier.ENTERPRISE:
        return True  # No restrictions for free/pro

    policy = await get_network_policy(ctx.workspace_id)
    if not policy.enabled:
        return True

    client_ip = request.client.host
    return ip_in_cidrs(client_ip, policy.allowed_ips)
```

---

## 3. Quotas & Limits

### 3.1 Tier Definitions

| Feature | Free | Pro | Enterprise |
|---------|------|-----|------------|
| **Pricing** | $0/mo | $99/mo | Custom |
| **Workspaces** | 1 | 5 | Unlimited |
| **Users** | 2 | 10 | Unlimited |
| **API Keys** | 1 | 10 | Unlimited |
| **Analyses/month** | 10 | 100 | Unlimited |
| **Rows/month** | 1,000 | 50,000 | 1,000,000+ |
| **LLM tokens/month** | 100K | 2M | Custom |
| **Storage** | 100 MB | 10 GB | 1 TB+ |
| **Retention** | 7 days | 90 days | Custom |
| **Support** | Community | Email | Dedicated |
| **SLA** | None | 99.5% | 99.9% |

### 3.2 Quota Schema

```python
@dataclass
class QuotaLimits:
    """Quota limits for a workspace"""
    workspace_id: str
    tier: Tier

    # Analysis limits
    max_analyses_per_month: int
    max_rows_per_month: int
    max_rows_per_analysis: int
    max_concurrent_analyses: int

    # Token limits
    max_llm_tokens_per_month: int
    max_llm_tokens_per_analysis: int

    # Storage limits
    max_storage_bytes: int
    max_retention_days: int

    # User limits
    max_users: int
    max_api_keys: int

    # Rate limits
    requests_per_minute: int
    burst_limit: int

@dataclass
class QuotaUsage:
    """Current usage for a workspace"""
    workspace_id: str
    period_start: date  # First of month

    # Current period usage
    analyses_count: int
    rows_count: int
    llm_tokens_count: int
    storage_bytes: int

    # Computed
    @property
    def analyses_remaining(self) -> int:
        return max(0, self.limits.max_analyses_per_month - self.analyses_count)
```

### 3.3 Quota Enforcement

```python
class QuotaEnforcer:
    """Enforces quota limits before job execution"""

    async def check_can_analyze(
        self,
        ctx: TenantContext,
        input_rows: int,
        estimated_tokens: int
    ) -> QuotaCheckResult:
        usage = await self.get_current_usage(ctx.workspace_id)
        limits = ctx.quotas

        violations = []

        # Check analyses count
        if usage.analyses_count >= limits.max_analyses_per_month:
            violations.append(QuotaViolation(
                quota="analyses_per_month",
                limit=limits.max_analyses_per_month,
                current=usage.analyses_count,
                requested=1
            ))

        # Check rows
        if usage.rows_count + input_rows > limits.max_rows_per_month:
            violations.append(QuotaViolation(
                quota="rows_per_month",
                limit=limits.max_rows_per_month,
                current=usage.rows_count,
                requested=input_rows
            ))

        if input_rows > limits.max_rows_per_analysis:
            violations.append(QuotaViolation(
                quota="rows_per_analysis",
                limit=limits.max_rows_per_analysis,
                current=0,
                requested=input_rows
            ))

        # Check tokens
        if usage.llm_tokens_count + estimated_tokens > limits.max_llm_tokens_per_month:
            violations.append(QuotaViolation(
                quota="llm_tokens_per_month",
                limit=limits.max_llm_tokens_per_month,
                current=usage.llm_tokens_count,
                requested=estimated_tokens
            ))

        # Check concurrent
        active = await self.get_active_analyses_count(ctx.workspace_id)
        if active >= limits.max_concurrent_analyses:
            violations.append(QuotaViolation(
                quota="concurrent_analyses",
                limit=limits.max_concurrent_analyses,
                current=active,
                requested=1
            ))

        return QuotaCheckResult(
            allowed=len(violations) == 0,
            violations=violations
        )

    async def record_usage(
        self,
        ctx: TenantContext,
        rows: int,
        tokens: int,
        storage_bytes: int
    ) -> None:
        """Record usage after job completion"""
        await self.persistence.increment_usage(
            workspace_id=ctx.workspace_id,
            period=date.today().replace(day=1),
            analyses_delta=1,
            rows_delta=rows,
            tokens_delta=tokens,
            storage_delta=storage_bytes
        )
```

### 3.4 Quota Error Responses

```json
{
  "error": {
    "code": "FA-QUOTA-001",
    "message": "Monthly analysis quota exceeded",
    "details": {
      "quota": "analyses_per_month",
      "limit": 10,
      "current": 10,
      "requested": 1,
      "resets_at": "2025-02-01T00:00:00Z"
    },
    "upgrade_url": "https://feedback-arrow.com/upgrade"
  }
}
```

---

## 4. Cost Attribution & Billing

### 4.1 Usage Tracking

**Tracked Metrics:**
```python
@dataclass
class UsageEvent:
    """Individual usage event for billing"""
    event_id: str
    timestamp: datetime
    workspace_id: str
    org_id: str

    # What was used
    event_type: str  # "analysis" | "storage" | "export"
    resource_id: str # analysis_id, etc.

    # Quantities
    rows_processed: int
    llm_tokens_input: int
    llm_tokens_output: int
    compute_seconds: float
    storage_bytes: int

    # Cost attribution
    provider_used: str       # "ollama" | "openai" | "anthropic"
    provider_model: str      # "gpt-4o-mini" | "claude-3-haiku"
    provider_cost_usd: float # Actual cost to us
```

**Token Counting:**
```python
class TokenCounter:
    """Count tokens for billing"""

    # Approximate token ratios by model family
    CHARS_PER_TOKEN = {
        "gpt": 4.0,
        "claude": 3.5,
        "llama": 4.0,
    }

    def estimate_tokens(self, text: str, model_family: str) -> int:
        chars_per_token = self.CHARS_PER_TOKEN.get(model_family, 4.0)
        return int(len(text) / chars_per_token)

    def count_actual(self, response: LLMResponse) -> TokenUsage:
        """Extract actual token usage from LLM response"""
        return TokenUsage(
            input_tokens=response.usage.prompt_tokens,
            output_tokens=response.usage.completion_tokens,
            total_tokens=response.usage.total_tokens
        )
```

### 4.2 Cost Allocation Formula

```python
@dataclass
class CostBreakdown:
    """Cost breakdown for billing"""
    llm_cost: float      # Token cost from provider
    compute_cost: float  # CPU/memory time
    storage_cost: float  # Data storage
    egress_cost: float   # Data export/transfer
    total_cost: float

def calculate_cost(event: UsageEvent) -> CostBreakdown:
    # LLM cost (provider-specific pricing)
    llm_cost = calculate_llm_cost(
        provider=event.provider_used,
        model=event.provider_model,
        input_tokens=event.llm_tokens_input,
        output_tokens=event.llm_tokens_output
    )

    # Compute cost ($0.0001 per CPU-second)
    compute_cost = event.compute_seconds * 0.0001

    # Storage cost ($0.023 per GB-month, prorated)
    storage_gb = event.storage_bytes / (1024**3)
    storage_cost = storage_gb * 0.023 / 30  # Daily rate

    # No egress cost for now (included in tier)
    egress_cost = 0.0

    return CostBreakdown(
        llm_cost=llm_cost,
        compute_cost=compute_cost,
        storage_cost=storage_cost,
        egress_cost=egress_cost,
        total_cost=llm_cost + compute_cost + storage_cost + egress_cost
    )

# LLM pricing table (per 1M tokens)
LLM_PRICING = {
    ("openai", "gpt-4o-mini"): {"input": 0.15, "output": 0.60},
    ("openai", "gpt-4o"): {"input": 2.50, "output": 10.00},
    ("anthropic", "claude-3-haiku"): {"input": 0.25, "output": 1.25},
    ("anthropic", "claude-3-sonnet"): {"input": 3.00, "output": 15.00},
    ("ollama", "*"): {"input": 0.00, "output": 0.00},  # Self-hosted
    ("vllm", "*"): {"input": 0.00, "output": 0.00},    # Self-hosted
}
```

### 4.3 Usage Aggregation

```python
class BillingAggregator:
    """Aggregate usage for billing periods"""

    async def get_monthly_invoice(
        self,
        org_id: str,
        year: int,
        month: int
    ) -> Invoice:
        period_start = date(year, month, 1)
        period_end = (period_start + timedelta(days=32)).replace(day=1)

        # Get all usage events for period
        events = await self.persistence.get_usage_events(
            org_id=org_id,
            start=period_start,
            end=period_end
        )

        # Aggregate by workspace
        workspace_summaries = {}
        for event in events:
            ws = workspace_summaries.setdefault(event.workspace_id, WorkspaceSummary())
            ws.add_event(event)

        # Calculate costs
        total_cost = sum(calculate_cost(e).total_cost for e in events)

        # Apply tier pricing
        org = await self.get_org(org_id)
        tier_base = TIER_PRICING[org.tier]

        return Invoice(
            org_id=org_id,
            period_start=period_start,
            period_end=period_end,
            tier=org.tier,
            tier_base_cost=tier_base,
            usage_cost=total_cost,
            total_cost=tier_base + total_cost,
            workspace_summaries=workspace_summaries,
            events_count=len(events)
        )
```

### 4.4 Usage Export Format

**CSV Export (for billing integration):**
```csv
date,workspace_id,event_type,rows,tokens_input,tokens_output,provider,cost_usd
2025-01-15,ws_abc123,analysis,1000,50000,10000,openai,0.0135
2025-01-15,ws_abc123,analysis,500,25000,5000,ollama,0.0000
2025-01-16,ws_abc123,storage,0,0,0,,0.0005
```

**JSON Export (detailed):**
```json
{
  "org_id": "org_acme123",
  "period": "2025-01",
  "currency": "USD",
  "summary": {
    "total_cost": 125.50,
    "tier_base": 99.00,
    "usage_cost": 26.50
  },
  "by_workspace": {
    "ws_abc123": {
      "analyses": 45,
      "rows": 23000,
      "tokens": 1250000,
      "cost": 26.50
    }
  },
  "by_provider": {
    "openai": {"tokens": 500000, "cost": 12.50},
    "ollama": {"tokens": 750000, "cost": 0.00}
  }
}
```

### 4.5 Cost Alerts

```python
@dataclass
class CostAlert:
    """Alert when cost threshold approached"""
    alert_id: str
    workspace_id: str
    threshold_type: str  # "absolute" | "percentage"
    threshold_value: float
    current_value: float
    triggered_at: datetime

ALERT_THRESHOLDS = [
    {"type": "percentage", "value": 80, "message": "80% of monthly budget used"},
    {"type": "percentage", "value": 100, "message": "Monthly budget exceeded"},
    {"type": "absolute", "value": 1000, "message": "Spending exceeded $1,000"},
]

async def check_cost_alerts(org_id: str) -> List[CostAlert]:
    usage = await get_current_month_usage(org_id)
    limits = await get_org_limits(org_id)

    alerts = []
    for threshold in ALERT_THRESHOLDS:
        if threshold["type"] == "percentage":
            current_pct = (usage.cost / limits.monthly_budget) * 100
            if current_pct >= threshold["value"]:
                alerts.append(CostAlert(...))
        elif threshold["type"] == "absolute":
            if usage.cost >= threshold["value"]:
                alerts.append(CostAlert(...))

    return alerts
```

---

## 5. Tenant Lifecycle

### 5.1 Provisioning Procedure

```
Step 1: Organization Creation
  └── Generate org_id
  └── Create billing account (Stripe)
  └── Set tier = TRIAL (14 days)
  └── Audit: tenant.created

Step 2: Default Workspace
  └── Generate ws_id
  └── Create default workspace "Main"
  └── Initialize quota counters
  └── Audit: workspace.created

Step 3: Owner User
  └── Generate usr_id
  └── Create user with OWNER role
  └── Send welcome email
  └── Audit: user.created

Step 4: Initial API Key
  └── Generate test key (fa_test_...)
  └── Show key once to user
  └── Audit: api_key.created
```

**Implementation:**
```python
class TenantProvisioner:
    async def provision(self, email: str, name: str) -> ProvisionResult:
        # Create organization
        org = Organization(
            org_id=generate_id("organization"),
            name=name,
            billing_email=email,
            tier=Tier.TRIAL,
            status=OrgStatus.TRIAL,
            created_at=datetime.utcnow(),
            metadata={"trial_ends": (datetime.utcnow() + timedelta(days=14)).isoformat()}
        )
        await self.persistence.save_org(org)

        # Create default workspace
        workspace = Workspace(
            workspace_id=generate_id("workspace"),
            org_id=org.org_id,
            name="Main",
            status=WorkspaceStatus.ACTIVE,
            settings=WorkspaceSettings.defaults(),
            created_at=datetime.utcnow()
        )
        await self.persistence.save_workspace(workspace)

        # Create owner user
        user = await self.user_service.create(
            email=email,
            org_id=org.org_id,
            workspace_ids=[workspace.workspace_id],
            role=Role.OWNER
        )

        # Create test API key
        api_key = APIKey.generate(
            tenant_id=workspace.workspace_id,
            environment="test",
            scopes=["*"]
        )
        await self.persistence.save_api_key(api_key)

        # Send welcome email
        await self.email_service.send_welcome(
            to=email,
            org_name=name,
            api_key=api_key.full_key  # Show once
        )

        return ProvisionResult(
            org=org,
            workspace=workspace,
            user=user,
            api_key_shown_once=api_key.full_key
        )
```

### 5.2 Data Export (Tenant Offboarding)

```python
class TenantExporter:
    """Export all tenant data for offboarding/portability"""

    async def export_all(self, workspace_id: str) -> ExportManifest:
        """Export all workspace data in portable formats"""
        export_id = generate_id("export")
        base_path = f"exports/{export_id}"

        # Export analyses and results
        analyses = await self.export_analyses(workspace_id, base_path)

        # Export configuration
        config = await self.export_config(workspace_id, base_path)

        # Export audit logs
        audit = await self.export_audit_logs(workspace_id, base_path)

        # Export user data
        users = await self.export_users(workspace_id, base_path)

        # Create manifest
        manifest = ExportManifest(
            export_id=export_id,
            workspace_id=workspace_id,
            created_at=datetime.utcnow(),
            files={
                "analyses": analyses,
                "config": config,
                "audit_logs": audit,
                "users": users
            },
            format_version="1.0",
            checksum=self.calculate_checksum(base_path)
        )

        await self.storage.write(f"{base_path}/manifest.json", manifest.to_json())

        return manifest
```

**Export Format:**
```
export_01hqx5k8n7gm/
├── manifest.json           # Export metadata
├── analyses/
│   ├── ana_001.parquet    # Analysis results (Arrow format)
│   ├── ana_002.parquet
│   └── metadata.json      # Analysis metadata
├── config/
│   ├── workspace.json     # Workspace settings
│   └── projects.json      # Project configurations
├── audit/
│   └── logs.parquet       # Audit trail
└── users/
    └── users.json         # User list (no passwords)
```

### 5.3 Data Deletion (GDPR Compliance)

```python
class TenantDeleter:
    """Delete all tenant data with GDPR compliance"""

    async def delete_workspace(self, workspace_id: str, reason: str) -> DeletionReport:
        """Soft delete with 30-day retention, then hard delete"""

        # Mark workspace as pending delete
        await self.persistence.update_workspace(
            workspace_id,
            status=WorkspaceStatus.PENDING_DELETE,
            delete_requested_at=datetime.utcnow(),
            delete_reason=reason
        )

        # Schedule hard deletion
        await self.scheduler.schedule(
            task="hard_delete_workspace",
            workspace_id=workspace_id,
            execute_at=datetime.utcnow() + timedelta(days=30)
        )

        # Audit
        await self.audit.log("workspace.delete_requested", {
            "workspace_id": workspace_id,
            "reason": reason,
            "hard_delete_at": (datetime.utcnow() + timedelta(days=30)).isoformat()
        })

        return DeletionReport(
            workspace_id=workspace_id,
            status="pending",
            hard_delete_at=datetime.utcnow() + timedelta(days=30)
        )

    async def hard_delete_workspace(self, workspace_id: str) -> DeletionReport:
        """Permanently delete all workspace data"""

        deleted_items = {
            "analyses": 0,
            "cache_entries": 0,
            "storage_files": 0,
            "database_records": 0
        }

        # Delete from object storage
        deleted_items["storage_files"] = await self.storage.delete_prefix(
            f"{workspace_id}/"
        )

        # Delete from cache
        deleted_items["cache_entries"] = await self.cache.delete_prefix(
            f"{workspace_id}:"
        )

        # Delete from database (cascade)
        deleted_items["database_records"] = await self.persistence.delete_workspace(
            workspace_id
        )

        # Audit (to separate audit store that outlives workspace)
        await self.audit.log("workspace.hard_deleted", {
            "workspace_id": workspace_id,
            "deleted_items": deleted_items
        })

        return DeletionReport(
            workspace_id=workspace_id,
            status="deleted",
            deleted_items=deleted_items
        )
```

### 5.4 Tenant Migration Between Tiers

```python
class TierMigrator:
    """Handle tier upgrades/downgrades"""

    async def upgrade(self, org_id: str, new_tier: Tier) -> MigrationResult:
        org = await self.persistence.get_org(org_id)
        old_tier = org.tier

        if new_tier.value <= old_tier.value:
            raise InvalidMigrationError("Use downgrade() for tier decreases")

        # Update tier immediately
        await self.persistence.update_org(org_id, tier=new_tier)

        # Apply new quotas
        for workspace in await self.persistence.get_workspaces(org_id):
            await self.quota_service.apply_tier_limits(workspace.workspace_id, new_tier)

        # Audit
        await self.audit.log("tier.upgraded", {
            "org_id": org_id,
            "old_tier": old_tier.value,
            "new_tier": new_tier.value
        })

        return MigrationResult(
            org_id=org_id,
            old_tier=old_tier,
            new_tier=new_tier,
            effective_immediately=True
        )

    async def downgrade(self, org_id: str, new_tier: Tier) -> MigrationResult:
        """Downgrade at end of billing period"""
        org = await self.persistence.get_org(org_id)
        old_tier = org.tier

        # Check if current usage exceeds new tier limits
        violations = await self.check_tier_compatibility(org_id, new_tier)
        if violations:
            return MigrationResult(
                org_id=org_id,
                old_tier=old_tier,
                new_tier=new_tier,
                blocked=True,
                violations=violations
            )

        # Schedule downgrade for end of billing period
        billing_period_end = await self.billing.get_period_end(org_id)

        await self.scheduler.schedule(
            task="apply_tier_downgrade",
            org_id=org_id,
            new_tier=new_tier.value,
            execute_at=billing_period_end
        )

        return MigrationResult(
            org_id=org_id,
            old_tier=old_tier,
            new_tier=new_tier,
            effective_at=billing_period_end
        )
```

---

## 6. Implementation Notes

### 6.1 Tenant Context Middleware

```python
class TenantContextMiddleware:
    """Extract and validate tenant context from request"""

    async def __call__(self, request: Request, call_next):
        # Extract auth
        auth_header = request.headers.get("Authorization")
        if not auth_header:
            raise AuthenticationError("Missing Authorization header")

        # Validate and extract context
        if auth_header.startswith("Bearer fa_"):
            # API key authentication
            ctx = await self.validate_api_key(auth_header[7:])
        elif auth_header.startswith("Bearer ey"):
            # JWT authentication
            ctx = await self.validate_jwt(auth_header[7:])
        else:
            raise AuthenticationError("Invalid Authorization format")

        # Attach to request state
        request.state.tenant_ctx = ctx

        # Process request
        response = await call_next(request)

        return response
```

### 6.2 Database Schema

```sql
-- Organizations
CREATE TABLE organizations (
    org_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    billing_email TEXT NOT NULL,
    tier TEXT NOT NULL DEFAULT 'trial',
    status TEXT NOT NULL DEFAULT 'trial',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB
);

-- Workspaces
CREATE TABLE workspaces (
    workspace_id TEXT PRIMARY KEY,
    org_id TEXT NOT NULL REFERENCES organizations(org_id),
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    settings JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Quota usage (monthly)
CREATE TABLE quota_usage (
    workspace_id TEXT NOT NULL REFERENCES workspaces(workspace_id),
    period_start DATE NOT NULL,
    analyses_count INTEGER NOT NULL DEFAULT 0,
    rows_count INTEGER NOT NULL DEFAULT 0,
    tokens_count BIGINT NOT NULL DEFAULT 0,
    storage_bytes BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (workspace_id, period_start)
);

-- Usage events (for billing)
CREATE TABLE usage_events (
    event_id TEXT PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    workspace_id TEXT NOT NULL REFERENCES workspaces(workspace_id),
    org_id TEXT NOT NULL REFERENCES organizations(org_id),
    event_type TEXT NOT NULL,
    resource_id TEXT,
    rows_processed INTEGER,
    llm_tokens_input INTEGER,
    llm_tokens_output INTEGER,
    compute_seconds FLOAT,
    storage_bytes BIGINT,
    provider_used TEXT,
    provider_model TEXT,
    provider_cost_usd DECIMAL(10, 6)
);

CREATE INDEX idx_usage_events_workspace ON usage_events(workspace_id, timestamp);
CREATE INDEX idx_usage_events_org ON usage_events(org_id, timestamp);
```

---

**Cross-References:**
- Authentication details: `SECURITY_SPEC.md`
- API error responses: `API_CONTRACT.md` Section 7
- Quota enforcement in pipeline: `PIPELINE_DEFINITION.md`
- Audit logging: `OPERATIONS_SPEC.md`
