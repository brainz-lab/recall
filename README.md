# Recall

Structured logging with total memory for Rails apps.

[![CI](https://github.com/brainz-lab/recall/actions/workflows/ci.yml/badge.svg)](https://github.com/brainz-lab/recall/actions/workflows/ci.yml)
[![Docker](https://github.com/brainz-lab/recall/actions/workflows/docker.yml/badge.svg)](https://github.com/brainz-lab/recall/actions/workflows/docker.yml)
[![Docker Hub](https://img.shields.io/docker/v/brainzllc/recall?label=Docker%20Hub)](https://hub.docker.com/r/brainzllc/recall)
[![Docs](https://img.shields.io/badge/docs-brainzlab.ai-orange)](https://docs.brainzlab.ai/products/recall/overview)

## Overview

Recall is a structured logging service that gives you total memory of your application's behavior. Unlike traditional logging, Recall stores logs as structured JSON with powerful querying capabilities.

- **Structured Logging** - JSON logs with automatic context
- **Powerful Search** - Query DSL for filtering and aggregation
- **Live Tail** - Real-time log streaming via WebSockets
- **Session Tracking** - Group logs by user session or request
- **MCP Integration** - AI-powered log analysis

## Quick Start

### With Docker

```bash
docker pull brainzllc/recall:latest
# or
docker pull ghcr.io/brainz-lab/recall:latest

docker run -d \
  -p 3000:3000 \
  -e DATABASE_URL=postgres://user:pass@host:5432/recall \
  -e REDIS_URL=redis://host:6379/1 \
  -e RAILS_MASTER_KEY=your-master-key \
  brainzllc/recall:latest
```

### Install SDK

```ruby
# Gemfile
gem 'brainzlab'
```

```ruby
# config/initializers/brainzlab.rb
BrainzLab.configure do |config|
  config.recall_key = ENV['RECALL_API_KEY']
end
```

### Send Logs

```ruby
BrainzLab::Recall.info("User signed up", user: user.as_json)
BrainzLab::Recall.error("Payment failed", error: e.message, amount: 99.99)
BrainzLab::Recall.debug("Cache hit", key: "user:123", ttl: 3600)
```

## Tech Stack

- **Ruby** 3.4.7
- **Rails** 8.1
- **PostgreSQL** 16 with JSONB + pg_trgm
- **Redis** 7
- **Hotwire** (Turbo + Stimulus)
- **Tailwind CSS**
- **Solid Queue** / **Solid Cache** / **Solid Cable**

## Query DSL

Recall uses a powerful query language for searching logs:

```
# Text search
"payment failed"

# Field filters
level:error env:production

# Time ranges
since:1h until:now

# Nested data
data.user.id:123

# Negation
level:!debug

# Combined
level:error env:production since:24h "connection timeout"

# Aggregation
since:1h | stats by:level
```

### Query Fields

| Field | Description | Example |
|-------|-------------|---------|
| `level` | Log level | `level:error` |
| `env` | Environment | `env:production` |
| `commit` | Git commit | `commit:abc123` |
| `branch` | Git branch | `branch:main` |
| `service` | Service name | `service:api` |
| `request_id` | Request ID | `request_id:req_xxx` |
| `session` | Session ID | `session:sess_xxx` |
| `since` | Start time | `since:1h`, `since:2024-01-01` |
| `until` | End time | `until:now` |
| `data.*` | Nested fields | `data.user.email:john@example.com` |

## API Endpoints

### Ingest
- `POST /api/v1/log` - Send single log
- `POST /api/v1/logs` - Batch send logs

### Query
- `GET /api/v1/logs?q=<query>` - Search logs
- `GET /api/v1/logs/:id` - Get single log

### Sessions
- `POST /api/v1/sessions` - Create session
- `GET /api/v1/sessions/:id/logs` - Get session logs
- `DELETE /api/v1/sessions/:id` - Clear session

### MCP
- `GET /mcp/tools` - List MCP tools
- `POST /mcp/tools/:name` - Call MCP tool
- `POST /mcp/rpc` - JSON-RPC endpoint

## MCP Tools

| Tool | Description |
|------|-------------|
| `recall_query` | Query logs with DSL |
| `recall_errors` | Get error/fatal logs |
| `recall_stats` | Statistics by level/commit/hour |
| `recall_by_session` | All logs for a session |
| `recall_new_session` | Create new session ID |
| `recall_clear_session` | Delete session logs |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection | Yes |
| `REDIS_URL` | Redis connection | Yes |
| `RAILS_MASTER_KEY` | Rails credentials | Yes |
| `BRAINZLAB_PLATFORM_URL` | Platform URL for auth | Yes |
| `SERVICE_KEY` | Internal service key | Yes |

## Log Payload Format

```json
{
  "level": "info",
  "message": "User signed up",
  "timestamp": "2024-12-21T10:00:00Z",
  "data": {
    "user": {
      "id": "user_123",
      "email": "john@example.com"
    }
  },
  "context": {
    "request_id": "req_abc123",
    "session_id": "sess_xyz789",
    "commit": "abc123",
    "branch": "main",
    "environment": "production",
    "service": "api",
    "host": "web-1"
  }
}
```

## Testing

```bash
bin/rails test              # Unit tests
bin/rails test:system       # System tests
bin/rubocop                 # Linting
```

## Documentation

Full documentation: [docs.brainzlab.ai/products/recall](https://docs.brainzlab.ai/products/recall/overview)

## Related

- [brainzlab-ruby](https://github.com/brainz-lab/brainzlab-ruby) - Ruby SDK
- [Reflex](https://github.com/brainz-lab/reflex) - Error tracking
- [Pulse](https://github.com/brainz-lab/pulse) - APM
- [Stack](https://github.com/brainz-lab/stack) - Self-hosted deployment

## License

MIT
