# PRD Schema

Task definitions for Ralph mode. Human-authored, machine-readable.

## prd.json

```json
{
  "feature": "Feature Name",
  "description": "Brief description of the overall feature",
  "created": "YYYY-MM-DD",
  "userStories": [
    {
      "id": "1.1",
      "title": "Short descriptive title",
      "description": "What this story accomplishes",
      "acceptance": [
        "Specific testable criteria 1",
        "Specific testable criteria 2"
      ],
      "dependsOn": [],
      "passes": false
    }
  ]
}
```

## Story Numbering

Stories numbered as `X.Y`:
- **X** = Phase number (1, 2, 3...)
- **Y** = Story sequence within phase (1, 2, 3...)

Phase numbers enable:
- Validation checkpoints at phase transitions
- Dependency tracking within and across phases
- Progress visualization (Phase 2: 3/4 complete)

## Right-Sizing Stories

**Right-sized (one session):**
- "Add email field to user profile form"
- "Create API endpoint for fetching tour dates"
- "Add confirmation modal to booking flow"

**Too big (break these down):**
- "Build the authentication system"
- "Create the entire dashboard"
- "Add full booking functionality"

## USER_STORIES.md (alternative)

Markdown alternative to prd.json for simpler projects:

```markdown
## Phase 1: Foundation
- [ ] Story 1.1: Setup project structure
- [ ] Story 1.2: Database models
- [x] Story 1.3: Basic API endpoints *(completed 2026-03-30)*

## Phase 2: Core Features
- [ ] Story 2.1: User authentication
- [ ] Story 2.2: Data validation
```

Check marks indicate completion. Both formats work — pick one per project.
