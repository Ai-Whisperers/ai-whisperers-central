# Backup & Recovery

Comprehensive backup and disaster recovery procedures.

## Backup Overview

| Data Type | Frequency | Retention | Location |
|-----------|-----------|-----------|----------|
| Database | Every 6 hours | 7 days | Local + S3 |
| Workflows | Daily | 30 days | Git + S3 |
| Config | On change | Last 10 | Git |
| Logs | Weekly | 30 days | S3 |
| Media | Weekly | 14 days | S3 |

## Automated Backups

### Enable Auto-Backup

```bash
# Edit crontab
crontab -e

# Add backup job (every 6 hours)
0 */6 * * * /opt/aiw-infra/scripts/backup.sh >> /var/log/backup.log 2>&1
```

### Backup Script Location

```bash
ls -la /opt/aiw-infra/scripts/backup.sh
```

## Manual Backup

### Database Backup

```bash
# Full database backup
cd /opt/aiw-infra
make backup-db

# Or manually
docker compose exec -T postgres pg_dump -U n8n n8n > backups/n8n-$(date +%Y%m%d-%H%M%S).sql

# Compressed backup
docker compose exec -T postgres pg_dump -U n8n n8n | gzip > backups/n8n-$(date +%Y%m%d).sql.gz
```

### Workflow Backup

```bash
# Export all workflows via API
curl -s http://localhost:5678/rest/workflows \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  | jq -r '.data[] | "\(.id)_\(.name).json"' \
  | while read f; do
      curl -s "http://localhost:5678/rest/workflows/$f" -o "backups/workflows/$f"
    done
```

### Configuration Backup

```bash
# Backup all config files
tar -czf backups/config-$(date +%Y%m%d).tar.gz \
  /opt/aiw-infra/.env \
  /opt/aiw-infra/traefik/ \
  /root/.hermes/ \
  /opt/n8n/
```

## Cloud Backup (S3)

### Configure S3 Backup

```bash
# Edit backup config
cat > /opt/aiw-infra/.backup-env << EOF
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
AWS_REGION=us-east-1
S3_BUCKET=aiw-backups
EOF
```

### Upload to S3

```bash
# Install AWS CLI
pip install awscli

# Configure
aws configure

# Upload backup
aws s3 cp backups/n8n-$(date +%Y%m%d).sql.gz s3://aiw-backups/daily/
```

### Automated S3 Upload

```bash
# Add to crontab
0 2 * * * aws s3 sync /opt/aiw-infra/backups s3://aiw-backups/ --delete
```

## Recovery Procedures

### Database Recovery

```bash
# 1. Stop n8n
docker compose stop n8n

# 2. Drop and recreate database
docker compose exec postgres psql -U n8n -d n8n -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# 3. Restore from backup
gunzip -c backups/n8n-YYYYMMDD.sql.gz | docker compose exec -T postgres psql -U n8n -d n8n

# 4. Restart n8n
docker compose up -d n8n

# 5. Verify
docker compose exec n8n wget -qO- http://localhost:5678/healthz
```

### Point-in-Time Recovery

```bash
# 1. Enable WAL archiving (if configured)
# 2. Find target time
docker compose exec postgres psql -U n8n -d n8n -c "SELECT pg_stop_backup();"

# 3. Restore to specific time
docker compose exec -T postgres pg_restore \
  --dbname=n8n \
  --clean \
  --no-owner \
  backups/n8n-full-backup.dump
```

### Workflow Recovery

```bash
# 1. List available backups
ls -la backups/workflows/

# 2. Restore specific workflow
WORKFLOW_ID="907ed14b-ec53-4b3b-aff6-6dda4da496bd"
curl -X PUT "http://localhost:5678/rest/workflows/$WORKFLOW_ID" \
  -H "Content-Type: application/json" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -d @backups/workflows/$WORKFLOW_ID.json
```

## Verification

### Test Backup Integrity

```bash
# Verify database backup
docker compose exec -T postgres psql -U n8n -d n8n < backups/n8n-test.sql -c "SELECT COUNT(*) FROM workflow_entity;"

# Verify S3 backup
aws s3 ls s3://aiw-backups/daily/ | tail -5

# Check backup script logs
tail -50 /var/log/backup.log
```

### Recovery Test

```bash
# Monthly recovery test (on staging)
./scripts/test-recovery.sh
```

## Backup Checklist

- [ ] Database backups running on schedule
- [ ] Workflow exports completing
- [ ] Config files in git
- [ ] S3 sync working
- [ ] Backup logs being monitored
- [ ] Recovery tested in last 30 days
- [ ] Offsite backups verified
- [ ] Team knows recovery procedures

## Retention Policy

```bash
# Cleanup old backups (run weekly)
find /opt/aiw-infra/backups -name "*.sql" -mtime +7 -delete
find /opt/aiw-infra/backups -name "*.gz" -mtime +7 -delete
find /opt/aiw-infra/backups -name "*.json" -mtime +30 -delete

# S3 lifecycle policy (configure in AWS console)
# Move to Glacier after 90 days
# Delete after 1 year
```
