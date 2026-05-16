# Kudos Agent — Backbone Design

**Date:** 2026-05-15
**Scope:** Agent + tools + triggers. UI review interface is a separate phase.

---

## Goal

A Rails app that ingests Slack messages (via webhook from Zapier or manual JSON file upload), uses a Claude-powered agent to extract kudos, and stores them for operator review.

---

## Stack

- Ruby on Rails (latest stable)
- PostgreSQL
- solid_queue (background jobs, no Redis)
- Claude API (tool_use) for the agent
- Hosted on Railway or Render (free tier)

---

## Database Schema

### `employees`
| column | type | notes |
|--------|------|-------|
| id | bigint PK | |
| first_name | string | not null |
| last_name | string | not null |
| username | string | unique, e.g. `sarah.park` |
| timestamps | | |

### `kudos`
| column | type | notes |
|--------|------|-------|
| id | bigint PK | |
| giver_id | bigint FK | → employees |
| receiver_id | bigint FK | → employees |
| reactions_from | string[] | usernames of taco reactors |
| reason | text | extracted by agent |
| category | string | extracted by agent (prompt-driven) |
| original_message | text | raw message text |
| slack_message_id | string | unique, for deduplication |
| slack_channel | string | |
| slack_timestamp | datetime | |
| status | string | default: `pending_review` |
| timestamps | | |

**Indexes:**
- `UNIQUE (slack_message_id)` — prevents duplicate kudos from re-uploads or duplicate webhook fires
- `INDEX (status)` — operator dashboard queries filter by status
- `INDEX (giver_id)`, `INDEX (receiver_id)` — future reporting

---

## Input Message Format

Both the webhook and file upload deliver messages in this structure:

```json
{
  "id": "msg_029",
  "author": "sarah.park",
  "channel": "#engineering",
  "text": "The flaky test in the auth suite was a race condition. Fixed in PR #418.",
  "timestamp": "2026-05-12T16:00:00Z",
  "reactions": [
    {"emoji": "taco", "user": "tom.chen"},
    {"emoji": "tada", "user": "alex.rivera"}
  ]
}
```

---

## Agent Design

### `KudosAgent`

Stateless. Receives a **batch of messages** (array), calls Claude API once with tool_use, and the agent makes tool calls for each kudos it finds across the whole batch. Single API call per batch amortises the fixed overhead of the system prompt (~800 tokens) and tool definitions (~500 tokens) across all messages.

**Batch size:** Default 50 messages, configurable via `KUDOS_BATCH_SIZE` env var. System prompt overhead (~1,300 tokens) is amortized across the batch — savings plateau around 50 messages. Beyond that, two costs grow: tool call context accumulates with each kudos found (Claude's tool_use loop carries full history each round), and output tokens (5-15× more expensive than input) scale with kudos count regardless of batch size. Reliability also degrades — a failed batch retries all N messages. Tune based on real token usage logs from production.

**System prompt:** Injectable string. Placeholder in v1 (`"Extract kudos from this Slack message."`). Categorization rules will be added in the next prompt engineering phase without touching Ruby code.

**Token usage:** In v1, all messages are sent to the agent regardless of reaction type — the agent determines whether a message contains kudos. This lets us find kudos in messages with no `:taco:` reaction.

```ruby
# FUTURE: pre-filter to taco-reacted messages only to reduce token costs.
# Uncomment once token usage has been measured in production:
# messages = messages.select { |m| m["reactions"]&.any? { |r| r["emoji"] == "taco" } }
```

Measure token usage after initial production traffic, then decide whether to enable the filter.

### Tools

**`find_or_create_employee`**

Input: `{ username: "sarah.park" }`

Behavior:
1. Split username on `.` → `first_name: "Sarah"`, `last_name: "Park"`
2. `Employee.find_or_create_by(username: username)` with name attributes
3. Return `{ id: <int> }`

**`record_kudos`**

Input:
```json
{
  "giver_id": 1,
  "receiver_id": 2,
  "reason": "Fixed the race condition in the auth suite",
  "category": "Technical Excellence",
  "original_message": "The flaky test...",
  "reactions_from": ["tom.chen"],
  "slack_message_id": "msg_029",
  "slack_channel": "#engineering",
  "slack_timestamp": "2026-05-12T16:00:00Z"
}
```

Behavior:
- `Kudos.find_or_create_by(slack_message_id:)` with all attributes
- `status` defaults to `pending_review`
- Returns `{ created: true/false }`

If the agent determines the message contains no kudos, it calls no tools and returns. No record is created.

---

## App Structure

```
app/
  agents/
    kudos_agent.rb
    tools/
      find_or_create_employee_tool.rb
      record_kudos_tool.rb
  jobs/
    kudos_extraction_job.rb     # shared job, called by all triggers
    scheduled_scan_job.rb       # boilerplate only
  controllers/
    webhooks_controller.rb      # POST /webhooks/slack
    uploads_controller.rb       # POST /uploads/slack
  models/
    employee.rb
    kudos.rb
```

---

## Triggers

### 1. Webhook — `POST /webhooks/slack`

- Source: Zapier job, fires on new Slack messages
- Payload: single message object (same format as above)
- Auth: shared secret in `X-Webhook-Secret` header, validated against env var
- Controller responds `200` immediately, enqueues `KudosExtractionJob` with a single-message array
- `KudosAgent` interface is uniform: always receives an array (1 message for webhooks, up to 25 for file uploads)

### 2. File Upload — `POST /uploads/slack`

- Source: operator manually uploads a Slack JSON export file
- Payload: multipart form with a `.json` file containing an array of messages
- Controller parses the array, slices it into batches of `KUDOS_BATCH_SIZE` (default 50), enqueues one `KudosExtractionJob` per batch
- Each job passes its batch of messages to `KudosAgent` in a single API call
- If a job fails and retries, already-created kudos are safely skipped via the unique index on `slack_message_id`

### 3. Scheduled Scan — boilerplate only

```ruby
# ScheduledScanJob
# future: will scan Slack history day-by-day via Zapier or Slack API
# and enqueue KudosExtractionJob for each message in the window
```

---

## Scale Considerations

- solid_queue with PostgreSQL handles hundreds of thousands of jobs without Redis
- Deduplication via unique index means re-uploads are safe — duplicate jobs silently no-op
- Claude API calls are async (inside jobs), so webhook response latency is unaffected
- File upload batches 50 messages per job (configurable) — overhead savings plateau ~50 msgs; beyond that, tool call context accumulation and output token cost dominate
- Token cost is the primary variable; pre-filter toggle is ready to enable once measured

---

## UI (Next Phase — Detail TBD)

Simple operator dashboard (Turbo + Tailwind):

```
[ Pending (42) ] [ Approved ] [ Rejected ]            [Search]

Giver        Receiver     Category    Reason            Date       Actions
──────────────────────────────────────────────────────────────────────────
Alice M.  →  Bob K.       Teamwork    "Saved the…"      May 14    ✓ ✗ ✎
Carol S.  →  Dave L.      Innovation  "Shipped the…"    May 13    ✓ ✗ ✎
```

- Approve / reject in-place with Turbo Streams
- Bulk actions for batch review
- Filter by status, category, date range

---

## Out of Scope (v1)

- Slack OAuth / bot token management
- Employee import / sync
- Reporting or analytics
- Email notifications
- Multi-tenant support
