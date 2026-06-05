# Issues & Problems Report

**Date:** April 13, 2026  
**VPS:** agentzero (72.61.44.159)

---

## 🔴 CRITICAL ISSUES

### 1. SSH Root Login Enabled
**Severity:** HIGH  
**Location:** `/etc/ssh/sshd_config`  
**Status:** `PermitRootLogin yes`

**Risk:** Anyone who obtains SSH credentials can log in as root.

**Recommendation:**
```bash
# Change to:
PermitRootLogin no
# Or use:
PermitRootLogin prohibit-password
```

---

### 2. SSH GatewayPorts Enabled
**Severity:** HIGH  
**Location:** `/etc/ssh/sshd_config`  
**Status:** `GatewayPorts yes`

**Risk:** SSH can be accessed from any interface, not just localhost.

**Recommendation:**
```bash
# Change to:
GatewayPorts no
```

---

## 🟠 MEDIUM ISSUES

### 3. n8n Python Task Runner Missing
**Severity:** MEDIUM  
**Location:** n8n container  
**Status:** Python 3 not installed in n8n container

**Error:**
```
Failed to start Python task runner in internal mode. 
because Python 3 is missing from this system.
```

**Impact:** Python Code nodes in n8n won't work.

**Recommendation:** 
- Install Python 3 in the n8n container
- Or configure external task runner mode
- See: https://docs.n8n.io/hosting/configuration/task-runners/

---

### 4. Zombie Process
**Severity:** MEDIUM  
**Process:** `schema-engine-d` (defunct)

**Impact:** Minor memory leak, process is stuck in zombie state.

**Recommendation:**
```bash
# Find parent process
ps aux | grep schema-engine-d
# Kill parent if safe
kill -9 <parent_pid>
```

---

### 5. Gemini Model Unhealthy
**Severity:** MEDIUM  
**Service:** LiteLLM  
**Model:** `gemini/gemini-2.5-flash`

**Status:** 20/21 models healthy (95%)

**Impact:** Gemini model won't be available for inference.

**Recommendation:** 
- Check Gemini API key validity
- Verify API quota hasn't been exceeded
- Consider removing from config if not needed

---

## 🟡 LOW ISSUES

### 6. Old Hostname in /etc/hosts
**Severity:** LOW  
**Location:** `/etc/hosts`  
**Status:** Contains `srv1396188.hstgr.cloud`

**Status:** ✅ Fixed - entry commented out

---

### 7. OpenClaw Directory Archived
**Severity:** INFO  
**Location:** `/opt/openclaw.old.archived/`

**Status:** Archived but not removed from disk (36MB)

**Recommendation:** Can be deleted after confirming no needed data.

---

### 8. N8N Task Runner Insecure Mode
**Severity:** LOW  
**Warning:**
```
TASK RUNNER CONFIGURED TO START IN INSECURE MODE. 
This is discouraged for production use.
```

**Impact:** Security risk for production environment.

**Recommendation:** Configure secure mode with proper authentication.

---

## ✅ WORKING CORRECTLY

### Services Status
| Service | Status | Notes |
|---------|--------|-------|
| LiteLLM | ✅ Working | 20/21 models |
| Grafana | ✅ Working | 11.5.0 |
| Prometheus | ✅ Working | v3.1.0 |
| Qdrant | ✅ Working | Collections OK |
| Hermes Agent | ✅ Working | GitHub sync OK |
| Evolution API | ✅ Working | WhatsApp connected |
| n8n | ⚠️ Working | Python missing |
| Docker Swarm | ✅ Working | 13 services |

### WhatsApp Pipeline
- Workflow: `907ed14b-ec53-4b3b-aff6-6dda4da496bd` (Nyx WhatsApp AI Pipeline)
- Status: Active
- Recent executions: All successful (247, 246, 245...)
- Webhook: `/webhook/whatsapp-incoming`

### GitHub Integration
- Hermes Agent syncing 30 PRs across 2 repos
- No errors in recent logs

---

## RECOMMENDED ACTIONS

### Immediate (Today)
1. [ ] Disable root SSH login
2. [ ] Disable GatewayPorts
3. [ ] Kill zombie process

### This Week
4. [ ] Install Python 3 in n8n OR configure external task runner
5. [ ] Verify/fix Gemini API key
6. [ ] Configure n8n task runner secure mode

### Next Sprint
7. [ ] Remove OpenClaw archived directory
8. [ ] Set up automated security monitoring
9. [ ] Configure fail2ban for SSH protection

---

## SECURITY CHECKLIST

- [x] Firewall (UFW) enabled
- [ ] Root login disabled
- [ ] Password authentication disabled
- [ ] SSH key-only authentication
- [ ] fail2ban installed
- [ ] Regular security updates
- [ ] Docker security scanning
- [ ] Secrets management (vaultwarden is running)

