---
id: templar.references.v1
kind: templar
version: 1.0.0
description: Structure template for references.md files
implements: references.create
globs: ""
governs: ""
requires: []
provenance: { owner: team-ticket, last_review: 2025-12-06 }
---

# {{ticket_id}} References

## Key Files
- `{{file_path}}` - {{file_description}}

## Documentation
- `{{doc_path}}` - {{doc_description}}

## Conversations
- `{{conversation_path}}` - {{conversation_description}}

## External Links
- [{{title}}]({{url}}) - {{description}}

