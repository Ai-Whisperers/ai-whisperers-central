---
id: templar.timeline.v1
kind: templar
version: 1.0.0
description: Structure template for timeline.md files
implements: timeline.track
globs: ""
governs: ""
requires: []
provenance: { owner: team-ticket, last_review: 2025-12-06 }
---

# {{ticket_id}} Timeline

## Conversation Timeline
- **{{conversation_timestamp}}**: {{filename}} - **{{type}}** - {{description}}

## Git Commit Timeline
- **{{commit_timestamp}}**: `{{hash}}` - {{commit_message}}

## Daily Event Timeline

### {{date}}
**{{time}}** - **{{type}}** - {{event_description}} ({{source}})

## Daily Summary

### {{date}} ({{day_type}})
**Total Verified Events**: {{count}}
**Work Hours**: {{start_time}} to {{end_time}} ({{duration}})
**Key Milestones**:
- {{milestone_1}}

