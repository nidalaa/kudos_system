# Kudos System

A Rails 8 application that automatically extracts, categorises, and manages peer recognition (kudos) from Slack messages using an AI agent powered by Claude.

## How it works

1. **Ingest** — Slack messages arrive via webhook or manual JSON upload
2. **Process** — A Claude-powered agent reads each message, identifies kudos, resolves employees and categories, and records the result
3. **Review** — A dashboard lets you approve, reject, filter, and search all extracted kudos

```
Slack export / webhook
        │
        ▼
 KudosExtractionJob
        │
        ▼
   KudosAgent (Claude claude-sonnet-4-6)
   ├── FindOrCreateEmployeeTool
   ├── FindOrCreateCategoryTool
   └── RecordKudosTool
        │
        ▼
   PostgreSQL (Kudos, Employee, Category)
        │
        ▼
   Review dashboard (/kudos-review)
```

## Features

- **AI extraction** — agent reads raw Slack messages and extracts structured kudos with giver, receiver, reason, and category
- **Emoji reactions** — all emoji reactions (taco, heart, fire, etc.) are stored per kudos and shown as tooltips
- **Review workflow** — approve or reject kudos individually or in bulk
- **Category filter** — filter the dashboard by category
- **Background jobs** — processing runs asynchronously via Solid Queue; monitor at `/jobs`
- **Deduplication** — unique index on `(slack_message_id, receiver_id)` prevents duplicate records

## Stack

| Layer | Technology |
|-------|------------|
| Framework | Rails 8.0 |
| Database | PostgreSQL + Solid Queue / Cache / Cable |
| AI | Anthropic Claude (claude-sonnet-4-6) |
| Frontend | Stimulus, Turbo, Tailwind CSS |
| Job dashboard | Mission Control Jobs |
| Deployment | Railway (Kamal-ready) |

## Setup

```bash
bundle install
cp .env.example .env        # add ANTHROPIC_API_KEY, DATABASE_URL
rails db:create db:migrate db:seed
rails server
```

### Environment variables

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Claude API key |
| `DATABASE_URL` | PostgreSQL connection string |
| `SLACK_SIGNING_SECRET` | Verifies incoming Slack webhooks |
| `JOBS_USERNAME` / `JOBS_PASSWORD` | Basic auth for `/jobs` dashboard |
| `KUDOS_UPLOAD_LIMIT` | Max messages per upload batch (default: 50) |

## Usage

### Upload a Slack export

Go to `/kudos-review`, click **Upload JSON**, and select a Slack export file. The agent processes messages in the background — refresh in a minute or two to see results.

### Webhook

`POST /webhooks/slack` — accepts standard Slack event payloads with HMAC signature verification.

### Review dashboard

| Action | How |
|--------|-----|
| Approve / Reject | Click per row or select multiple → bulk action |
| Edit category | Click the pencil icon on any row |
| Filter by category | Use the dropdown in the toolbar |
| Search | Full-text search across all fields |
| Delete all | Red button in the toolbar (with confirmation) |

## Development

```bash
rails server        # app on :3000
bundle exec rspec   # run tests
```

Background jobs run inline in development (`config.active_job.queue_adapter = :inline`).
