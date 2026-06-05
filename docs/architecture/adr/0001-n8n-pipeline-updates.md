# 0001. n8n Pipeline Updates via PostgreSQL

Date: 2026-04-13

## Status

Accepted

## Context

n8n v2.14+ has a draft/published workflow system. Simply updating `workflow_entity.nodes` via SQL does not reliably publish changes. The pipeline must be active and the published version must be updated for webhook triggers to use the new code.

## Decision

Update n8n pipeline nodes via PostgreSQL SQL with the following procedure:

1. **workflow_history** (FK constraint requires this first)
   ```sql
   UPDATE workflow_history 
   SET nodes = $jn$<new_nodes_json>$jn$
   WHERE "workflowId" = '<workflow-id>'
     AND "versionId" = '<versionId>';
   ```

2. **workflow_entity** (main workflow record)
   ```sql
   UPDATE workflow_entity 
   SET nodes = $jn$<new_nodes_json>$jn$,
       "versionId" = '<new-version-uuid>'
   WHERE id = '<workflow-id>';
   ```

3. **workflow_published_version** (published version reference)
   ```sql
   UPDATE workflow_published_version 
   SET "publishedVersionId" = '<new-version-uuid>'
   WHERE "workflowId" = '<workflow-id>';
   ```

4. **Force restart** — n8n must be restarted to pick up changes:
   ```bash
   docker service update --force n8n_n8n
   ```

## Key Insights

- Use **PostgreSQL dollar-quoting** (`$jn$...$jn$`) for JSON injection — single quotes and double quotes in the JS code require it
- Verify `$` signs in n8n expressions survived the update (shell heredocs strip `$`)
- The `workflow_history` table caches the published nodes and MUST be updated or n8n uses the old cached version
- n8n v2.16 reads from `workflow_history.nodes` when `workflow_entity.versionId` matches `workflow_published_version.publishedVersionId`

## Consequences

### Positive
- Direct SQL updates are fast and auditable
- No need to export/import workflow JSON
- Changes are immediately persisted

### Negative
- Risk of corrupting workflow if JSON is malformed
- Must manually track version IDs
- No n8n UI visibility of pending changes

### Risks
- n8n version upgrades may change the schema
- Workflow cache invalidation is not immediate — requires restart
