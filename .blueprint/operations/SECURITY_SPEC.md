# Security Specification

**Purpose:** Authentication, authorization, encryption, and compliance for multi-tenant SaaS
**Status:** Authoritative
**Date:** 2025-12-19

---

## 1. Authentication Model

### 1.1 API Key Authentication (Primary)

**Format:** `fa_{environment}_{random}`

```
fa_live_abc123def456ghi789jkl012mno345  # Production key
fa_test_abc123def456ghi789jkl012mno345  # Test/sandbox key
fa_dev_abc123def456ghi789jkl012mno345   # Development key
```

**Specification:**
```python
@dataclass
class APIKey:
    prefix: str           # "fa"
    environment: str      # "live" | "test" | "dev"
    secret: str           # 32-character random string (base62)

    # Derived/stored
    key_id: str           # Hash of full key (for lookup)
    tenant_id: str        # Owner tenant
    created_at: datetime
    expires_at: Optional[datetime]
    last_used_at: Optional[datetime]
    scopes: List[str]     # Allowed operations

    @property
    def full_key(self) -> str:
        return f"{self.prefix}_{self.environment}_{self.secret}"

    @staticmethod
    def generate(tenant_id: str, environment: str, scopes: List[str]) -> "APIKey":
        secret = secrets.token_urlsafe(24)[:32]  # 32 chars base62
        return APIKey(
            prefix="fa",
            environment=environment,
            secret=secret,
            key_id=hashlib.sha256(f"fa_{environment}_{secret}".encode()).hexdigest()[:16],
            tenant_id=tenant_id,
            created_at=datetime.utcnow(),
            expires_at=None,
            last_used_at=None,
            scopes=scopes
        )
```

**HTTP Header:**
```
Authorization: Bearer fa_live_abc123def456ghi789jkl012mno345
```

**Key Storage:**
- Only `key_id` (hash) stored in database
- Full key shown ONCE at creation time
- Keys are hashed with SHA-256 before storage
- Never log full API keys

### 1.2 JWT Session Tokens (Web UI)

**Use Case:** Browser-based dashboard sessions

**Structure (RFC 7519):**
```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "key-2025-01"
  },
  "payload": {
    "iss": "https://api.feedback-arrow.com",
    "sub": "user_abc123",
    "aud": "feedback-arrow",
    "iat": 1734567890,
    "exp": 1734571490,
    "tenant_id": "tenant_xyz789",
    "roles": ["admin"],
    "scopes": ["analyze:write", "export:read"]
  }
}
```

**Token Lifetimes:**
| Token Type | Lifetime | Refresh |
|------------|----------|---------|
| Access Token | 1 hour | Via refresh token |
| Refresh Token | 7 days | Sliding window |
| API Key | No expiry (default) | Manual rotation |

**Key Rotation:**
- RSA key pairs rotated every 90 days
- Previous key valid for 7 days after rotation
- `kid` header identifies active key

### 1.3 OAuth2 Flows (Integrations)

**Supported Flows:**
```
┌─────────────────────────────────────────────────────────┐
│ Flow               │ Use Case                          │
├─────────────────────────────────────────────────────────┤
│ Client Credentials │ Server-to-server (M2M)            │
│ Authorization Code │ User-authorized integrations      │
│ PKCE               │ Public clients (SPAs, mobile)     │
└─────────────────────────────────────────────────────────┘
```

**OAuth2 Endpoints:**
```
POST /oauth/token           # Token exchange
GET  /oauth/authorize       # Authorization (user consent)
POST /oauth/revoke          # Token revocation
GET  /.well-known/openid-configuration
```

### 1.4 Key Rotation Procedure

```
Step 1: Generate new key
  └── New key created with same scopes
  └── Old key still active

Step 2: Grace period (7 days default)
  └── Both keys accept requests
  └── Deprecation warning in response headers

Step 3: Deactivate old key
  └── Old key returns 401
  └── Audit log: "key_rotated"

Step 4: Delete old key (30 days)
  └── Key record purged from database
```

---

## 2. Authorization Model (RBAC)

### 2.1 Role Definitions

```python
class Role(Enum):
    OWNER = "owner"      # Full control, billing, delete tenant
    ADMIN = "admin"      # Manage users, API keys, settings
    ANALYST = "analyst"  # Run analysis, view results
    VIEWER = "viewer"    # Read-only access to results
```

**Role Hierarchy:**
```
owner
  └── admin
        └── analyst
              └── viewer
```

### 2.2 Permission Matrix

| Permission | Owner | Admin | Analyst | Viewer |
|------------|-------|-------|---------|--------|
| **Analysis** |
| `analyze:create` | ✓ | ✓ | ✓ | ✗ |
| `analyze:read` | ✓ | ✓ | ✓ | ✓ |
| `analyze:cancel` | ✓ | ✓ | ✓ | ✗ |
| **Results** |
| `results:read` | ✓ | ✓ | ✓ | ✓ |
| `results:export` | ✓ | ✓ | ✓ | ✗ |
| `results:delete` | ✓ | ✓ | ✗ | ✗ |
| **Users** |
| `users:read` | ✓ | ✓ | ✗ | ✗ |
| `users:invite` | ✓ | ✓ | ✗ | ✗ |
| `users:remove` | ✓ | ✓ | ✗ | ✗ |
| `users:change_role` | ✓ | ✗ | ✗ | ✗ |
| **API Keys** |
| `keys:create` | ✓ | ✓ | ✗ | ✗ |
| `keys:list` | ✓ | ✓ | ✗ | ✗ |
| `keys:revoke` | ✓ | ✓ | ✗ | ✗ |
| **Settings** |
| `settings:read` | ✓ | ✓ | ✓ | ✓ |
| `settings:write` | ✓ | ✓ | ✗ | ✗ |
| **Billing** |
| `billing:read` | ✓ | ✗ | ✗ | ✗ |
| `billing:manage` | ✓ | ✗ | ✗ | ✗ |
| **Tenant** |
| `tenant:delete` | ✓ | ✗ | ✗ | ✗ |

### 2.3 API Key Scopes

**Scope Format:** `resource:action`

```python
VALID_SCOPES = [
    "analyze:create",
    "analyze:read",
    "results:read",
    "results:export",
    "providers:read",
    "*",  # Full access (owner only)
]
```

**Scope Validation:**
```python
def check_scope(required: str, granted: List[str]) -> bool:
    if "*" in granted:
        return True
    if required in granted:
        return True
    # Check wildcard patterns
    resource, action = required.split(":")
    if f"{resource}:*" in granted:
        return True
    return False
```

### 2.4 Tenant-Scoped Authorization

All authorization checks include tenant context:

```python
@dataclass
class AuthContext:
    user_id: Optional[str]      # None for API key auth
    api_key_id: Optional[str]   # None for JWT auth
    tenant_id: str              # Always required
    roles: List[Role]
    scopes: List[str]

def authorize(ctx: AuthContext, permission: str, resource_tenant: str) -> bool:
    # Tenant isolation check
    if ctx.tenant_id != resource_tenant:
        return False

    # Permission check
    return has_permission(ctx.roles, permission)
```

---

## 3. Encryption

### 3.1 Secrets at Rest

**ISecretStore Encryption:**
```python
class EncryptedSecretStore(ISecretStore):
    """Secrets encrypted with AES-256-GCM before storage"""

    def __init__(self, backend: ISecretStore, master_key: bytes):
        self.backend = backend
        self.cipher = AESGCM(master_key)

    async def set_secret(self, name: str, value: str) -> None:
        nonce = os.urandom(12)
        encrypted = self.cipher.encrypt(nonce, value.encode(), None)
        # Store as: nonce || ciphertext
        await self.backend.set_secret(name, base64.b64encode(nonce + encrypted).decode())

    async def get_secret(self, name: str) -> str:
        data = base64.b64decode(await self.backend.get_secret(name))
        nonce, ciphertext = data[:12], data[12:]
        return self.cipher.decrypt(nonce, ciphertext, None).decode()
```

**Master Key Management:**
```
Production:   AWS KMS / GCP Cloud KMS / Azure Key Vault
Development:  Environment variable (MASTER_KEY)
Testing:      Hardcoded test key (never in prod)
```

### 3.2 Data at Rest

**Parquet Encryption (Optional for Sensitive Data):**
```python
# PyArrow Parquet encryption configuration
encryption_config = pq.encryption.EncryptionConfiguration(
    footer_key="footer_key_name",
    column_keys={
        "customer_comment": "pii_key",
        "pain_point_verbatim": "pii_key",
    },
    encryption_algorithm="AES_GCM_V1",
    data_key_length_bits=256,
)

# KMS client for key retrieval
kms_connection_config = pq.encryption.KmsConnectionConfig(
    kms_instance_url=os.environ["KMS_URL"],
)
```

**Database Encryption:**
- DuckDB: Encrypted at filesystem level (dm-crypt/LUKS)
- PostgreSQL: TDE or column-level encryption for PII
- Redis: TLS + at-rest encryption (cloud providers)

### 3.3 Data in Transit

**TLS Requirements:**
```
Minimum Version:  TLS 1.3 (TLS 1.2 with strong ciphers as fallback)
Cipher Suites:
  - TLS_AES_256_GCM_SHA384
  - TLS_CHACHA20_POLY1305_SHA256
  - TLS_AES_128_GCM_SHA256

Certificate:
  - RSA 2048-bit minimum (4096-bit preferred)
  - Or ECDSA P-256/P-384
  - Renewed 30 days before expiry

HSTS:            max-age=31536000; includeSubDomains; preload
```

**Internal Service Communication:**
```
Option A: mTLS (mutual TLS)
  - Each service has client certificate
  - Certificate rotation via cert-manager

Option B: Service Mesh (Istio/Linkerd)
  - Automatic mTLS between pods
  - Zero-trust network model
```

### 3.4 PII Masking Strategy

**Identified PII Fields:**
```python
PII_FIELDS = [
    "customer_comment",      # May contain names, emails
    "pain_point_verbatim",   # User-generated content
    "contact_info",          # If captured
]
```

**Masking Levels:**
```python
class MaskingLevel(Enum):
    NONE = "none"           # No masking (internal use)
    PARTIAL = "partial"     # Show first/last chars: j***@e***.com
    FULL = "full"           # Replace with [REDACTED]
    HASH = "hash"           # SHA-256 hash (for matching without exposure)

def mask_pii(value: str, level: MaskingLevel, field_type: str) -> str:
    if level == MaskingLevel.NONE:
        return value
    if level == MaskingLevel.FULL:
        return "[REDACTED]"
    if level == MaskingLevel.HASH:
        return f"sha256:{hashlib.sha256(value.encode()).hexdigest()[:16]}"
    # PARTIAL masking by field type
    if field_type == "email":
        user, domain = value.split("@")
        return f"{user[0]}***@{domain[0]}***.{domain.split('.')[-1]}"
    return f"{value[0]}{'*' * (len(value) - 2)}{value[-1]}"
```

**Masking Application:**
```
Export to external:  FULL masking by default
Internal dashboard:  PARTIAL masking
Logs:                FULL masking always
Audit trail:         HASH for correlation
```

---

## 4. Compliance & Audit

### 4.1 Audit Log Schema

```python
@dataclass
class AuditEvent:
    # Identity
    event_id: str           # UUID
    timestamp: datetime     # UTC, ISO 8601

    # Who
    actor_type: str         # "user" | "api_key" | "system"
    actor_id: str           # user_id or key_id
    tenant_id: str

    # What
    action: str             # "analyze.created" | "user.invited" | ...
    resource_type: str      # "analysis" | "user" | "api_key" | ...
    resource_id: str

    # Context
    ip_address: str
    user_agent: str
    request_id: str         # Correlation ID

    # Details
    changes: Optional[Dict] # Before/after for mutations
    metadata: Dict          # Additional context

    # Outcome
    status: str             # "success" | "failure" | "denied"
    error_code: Optional[str]

# Arrow schema for efficient storage
AUDIT_SCHEMA = pa.schema([
    ("event_id", pa.string()),
    ("timestamp", pa.timestamp("us", tz="UTC")),
    ("actor_type", pa.string()),
    ("actor_id", pa.string()),
    ("tenant_id", pa.string()),
    ("action", pa.string()),
    ("resource_type", pa.string()),
    ("resource_id", pa.string()),
    ("ip_address", pa.string()),
    ("user_agent", pa.string()),
    ("request_id", pa.string()),
    ("changes", pa.string()),  # JSON
    ("metadata", pa.string()), # JSON
    ("status", pa.string()),
    ("error_code", pa.string()),
])
```

**Audit Actions:**
```
Authentication:
  auth.login_success
  auth.login_failure
  auth.logout
  auth.key_created
  auth.key_revoked
  auth.key_rotated

Analysis:
  analyze.created
  analyze.completed
  analyze.failed
  analyze.cancelled

Data:
  results.exported
  results.deleted
  data.uploaded

Users:
  user.invited
  user.removed
  user.role_changed

Settings:
  settings.updated
  quota.exceeded

Tenant:
  tenant.created
  tenant.suspended
  tenant.deleted
```

### 4.2 GDPR Right-to-be-Forgotten

**Data Subject Request (DSR) Procedure:**

```
Step 1: Request Received (T+0)
  └── Log DSR: dsr.received
  └── Verify identity (email confirmation)
  └── Acknowledge within 72 hours

Step 2: Data Discovery (T+3 days max)
  └── Query all systems for data_subject_id
  └── Generate data inventory report

Step 3: Review (T+7 days)
  └── Identify data with legal retention requirements
  └── Identify data that can be deleted

Step 4: Execution (T+14 days)
  └── Delete deletable data
  └── Anonymize retained data (legal hold)
  └── Update all replicas, backups within 30 days

Step 5: Confirmation (T+30 days max)
  └── Send deletion confirmation to data subject
  └── Log DSR: dsr.completed
```

**Implementation:**
```python
class GDPRService:
    async def process_deletion_request(self, data_subject_id: str) -> DSRResult:
        # Find all data
        locations = await self.data_discovery.find_all(data_subject_id)

        for location in locations:
            if location.has_legal_hold:
                # Anonymize instead of delete
                await self.anonymize(location, data_subject_id)
            else:
                await self.delete(location)

        # Schedule backup purge
        await self.backup_purge_queue.enqueue(
            data_subject_id,
            execute_after=timedelta(days=30)
        )

        return DSRResult(
            deleted_records=len([l for l in locations if not l.has_legal_hold]),
            anonymized_records=len([l for l in locations if l.has_legal_hold]),
            backup_purge_scheduled=True
        )
```

### 4.3 Data Retention Policies

| Data Type | Retention | After Retention | Legal Basis |
|-----------|-----------|-----------------|-------------|
| Analysis results | 90 days | Delete | Contract |
| Audit logs | 7 years | Archive cold | Legal compliance |
| User data | Account lifetime + 30 days | Delete | Consent |
| Billing records | 7 years | Archive cold | Tax law |
| API access logs | 30 days | Delete | Security |
| Error logs | 14 days | Delete | Operations |

**Retention Enforcement:**
```python
class RetentionEnforcer:
    """Scheduled job to enforce retention policies"""

    POLICIES = {
        "analysis_results": timedelta(days=90),
        "api_logs": timedelta(days=30),
        "error_logs": timedelta(days=14),
    }

    async def enforce(self):
        for data_type, retention in self.POLICIES.items():
            cutoff = datetime.utcnow() - retention
            deleted = await self.storage.delete_older_than(data_type, cutoff)
            await self.audit.log("retention.enforced", {
                "data_type": data_type,
                "deleted_count": deleted,
                "cutoff": cutoff.isoformat()
            })
```

### 4.4 SOC2 Control Mappings

| SOC2 Control | Implementation |
|--------------|----------------|
| **CC6.1** Access Control | RBAC + API key scopes |
| **CC6.2** Authentication | API keys + JWT + OAuth2 |
| **CC6.3** Authorization | Permission matrix per role |
| **CC6.6** Encryption | TLS 1.3 + AES-256-GCM at rest |
| **CC6.7** Key Management | KMS integration, 90-day rotation |
| **CC7.1** Change Management | Audit log on all mutations |
| **CC7.2** Monitoring | Real-time audit streaming |
| **CC8.1** Incident Response | Security runbooks |

---

## 5. Security Runbooks

### 5.1 Key Compromise Response

**Severity:** P1 (Critical)
**Response Time:** < 15 minutes

```
DETECT:
  └── Alert: Unusual API key usage pattern
  └── Alert: Key used from unexpected IP/region
  └── Report: Customer reports unauthorized access

CONTAIN (< 5 min):
  1. Immediately revoke suspected key
     $ fa-admin keys revoke <key_id> --reason "suspected_compromise"

  2. Block IP addresses if known
     $ fa-admin firewall block <ip> --duration 24h

  3. Enable enhanced logging for tenant
     $ fa-admin tenant set-flag <tenant_id> enhanced_audit true

INVESTIGATE (< 2 hours):
  1. Pull all requests for compromised key
     SELECT * FROM audit_log WHERE api_key_id = '<key_id>' ORDER BY timestamp DESC

  2. Identify data accessed/modified
  3. Determine attack vector (leak, theft, brute force)

REMEDIATE:
  1. Generate new key for customer
  2. Rotate any related secrets
  3. Notify customer with incident summary
  4. Update firewall rules if needed

POST-INCIDENT:
  1. Complete incident report within 24 hours
  2. Update detection rules
  3. Customer communication within 72 hours
```

### 5.2 Breach Notification Procedure

**Timeline (GDPR Compliant):**

```
T+0:        Breach detected
T+1 hour:   Initial assessment complete
T+24 hours: Internal incident report
T+72 hours: Notify supervisory authority (if required)
T+72 hours: Notify affected data subjects (if high risk)
```

**Notification Template:**
```
Subject: Security Incident Notification - [Incident ID]

Dear [Customer],

We are writing to inform you of a security incident that may have
affected your data in the Feedback Arrow service.

What happened:
[Brief description]

What data was involved:
[List of affected data types]

What we are doing:
[Remediation steps]

What you can do:
[Recommended actions]

For questions, contact: security@feedback-arrow.com

Incident ID: [ID]
Date detected: [Date]
```

### 5.3 Security Incident Classification

| Severity | Description | Response Time | Escalation |
|----------|-------------|---------------|------------|
| **P1 Critical** | Active breach, data exfiltration | < 15 min | CEO, Legal, CISO |
| **P2 High** | Vulnerability actively exploited | < 1 hour | Engineering Lead, Security |
| **P3 Medium** | Potential vulnerability, no exploit | < 4 hours | Security Team |
| **P4 Low** | Security improvement needed | < 24 hours | Security Team |

---

## 6. Security Headers

**Required HTTP Response Headers:**
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 0
Content-Security-Policy: default-src 'self'; frame-ancestors 'none'
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

**Rate Limit Headers:**
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1734567890
Retry-After: 60  # When rate limited
```

---

## 7. Security Testing Requirements

### 7.1 Automated Scans

| Scan Type | Frequency | Tool |
|-----------|-----------|------|
| Dependency vulnerabilities | Every commit | Dependabot, Snyk |
| SAST (static analysis) | Every commit | Semgrep, Bandit |
| DAST (dynamic analysis) | Weekly | OWASP ZAP |
| Container scanning | Every build | Trivy |
| Secret scanning | Every commit | GitLeaks, TruffleHog |

### 7.2 Penetration Testing

- **Frequency:** Annually (minimum), after major releases
- **Scope:** Full application + API + infrastructure
- **Provider:** Third-party security firm
- **Remediation:** P1/P2 within 30 days, P3/P4 within 90 days

---

**Cross-References:**
- Authentication flow: `API_CONTRACT.md` Section 6
- Tenant isolation: `MULTI_TENANCY_SPEC.md`
- Secret storage: `STATE_STORE_SPEC.md` ISecretStore
- Audit logging: `OPERATIONS_SPEC.md`
