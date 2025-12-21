# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Recall by Brainz Lab

Structured logging with total memory for Rails apps. First product in the Brainz Lab suite.

**Domain**: recall.brainzlab.ai

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          RECALL (Rails 8)                        │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Dashboard   │  │     API      │  │  MCP Server  │           │
│  │  (Hotwire)   │  │  (JSON API)  │  │   (Ruby)     │           │
│  │ /dashboard/* │  │  /api/v1/*   │  │   /mcp/*     │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                           │                  │                   │
│                           ▼                  ▼                   │
│              ┌─────────────────────────────────────┐            │
│              │       PostgreSQL + JSONB            │            │
│              └─────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                              ▲
            ┌─────────────────┴─────────────────┐
            │                                    │
    ┌───────┴───────┐                  ┌────────┴────────┐
    │  SDK (Gem)    │                  │   Claude/AI     │
    │ brainzlab-sdk │                  │  (Uses MCP)     │
    └───────────────┘                  └─────────────────┘
```

## Tech Stack

- **Backend**: Rails 8 API + Dashboard
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database**: PostgreSQL with JSONB + pg_trgm for text search
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable (live tail)
- **MCP Server**: Ruby (integrated into Rails)

## Common Commands

```bash
# Development
bin/rails server
bin/rails console
bin/rails db:migrate

# Testing
bin/rails test
bin/rails test test/models/log_entry_test.rb  # single file
bin/rails test test/models/log_entry_test.rb:42  # single test by line

# Docker
docker-compose up
docker-compose exec web bin/rails db:migrate

# Database
bin/rails db:create db:migrate
bin/rails db:seed
```

## Key Models

- **Project**: Has `ingest_key` (rcl_ingest_xxx) and `api_key` (rcl_api_xxx)
- **LogEntry**: JSONB `data` field, indexed for queries. Fields: timestamp, level, message, commit, branch, environment, service, host, request_id, session_id

## Query DSL (Recall Query Language)

The `QueryParser` service parses a query string into filters:

```
[text search] [field:value]... [| command]
```

**Fields**: level, env, commit, branch, service, request_id, session, since, until, data.*

**Examples**:
- `level:error since:1h` - errors in last hour
- `"payment failed" env:production` - text search in production
- `data.user.id:123 level:error` - errors for specific user
- `since:15m | stats by:level` - stats grouped by level

**Negation**: `level:!debug` excludes debug logs

## MCP Tools

| Tool | Description |
|------|-------------|
| `recall_query` | Query with DSL |
| `recall_errors` | Get error/fatal logs |
| `recall_stats` | Get statistics grouped by level/commit/hour/day |
| `recall_by_session` | Get all logs for a session |
| `recall_new_session` | Create new session ID |
| `recall_clear_session` | Delete logs for a session |

## API Endpoints

- `POST /api/v1/log` - Ingest single log
- `POST /api/v1/logs` - Batch ingest
- `GET /api/v1/logs?q=<query>` - Query logs
- `POST /api/v1/sessions` - Create session
- `DELETE /api/v1/sessions/:id` - Clear session

Authentication: `Authorization: Bearer <key>` or `X-API-Key: <key>`

## SDK (brainzlab-sdk gem)

Separate repository. Client usage:

```ruby
gem 'brainzlab-sdk'

BrainzLab::Recall.configure do |c|
  c.key = ENV['RECALL_KEY']
end

BrainzLab::Recall.info("User signed up", user: user.as_json)
BrainzLab::Recall.error("Payment failed", error: e.message, user_id: user.id)
```

Features: automatic buffering, session management, request context via middleware

## Design Principles

- Clean, minimal UI like Anthropic/Claude
- Use Hotwire for real-time updates (live tail via ActionCable)
- JSONB for flexible structured data
- GIN indexes for fast JSONB and text search
