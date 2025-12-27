# Brainz Logs - With Query DSL

## Overview

Logs with a powerful, SQL-like query language that works for humans AND AI.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           BRAINZ LOGS                                        │
│                    "Query logs like you query data"                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                      │   │
│  │  > level:error commit:abc123 since:1h                               │   │
│  │                                                                      │   │
│  │  > data.user.id:123 level:error,warn                                │   │
│  │                                                                      │   │
│  │  > "payment failed" env:production branch:main                      │   │
│  │                                                                      │   │
│  │  > request_id:req-xxx | stats by:level                              │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Dashboard for humans. MCP for AI. Same query language.                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## The Query DSL

### Basic Syntax

```
[text search] [field:value] [field:value] ... [| command]
```

### Field Filters

```bash
# Exact match
level:error
env:production
commit:abc123f
branch:main
service:api

# Multiple values (OR)
level:error,warn,fatal
env:production,staging

# Negation
level:!debug
env:!development

# Exists / Not exists
user_id:*          # has user_id
user_id:!*         # no user_id
```

### Time Filters

```bash
# Relative time
since:5m           # last 5 minutes
since:1h           # last 1 hour
since:24h          # last 24 hours
since:7d           # last 7 days

# Time range
since:1h until:30m    # between 1 hour ago and 30 minutes ago

# Absolute time
since:2024-01-15
since:2024-01-15T10:00:00Z
until:2024-01-15T12:00:00Z
```

### Text Search

```bash
# Contains (anywhere in message)
"payment failed"
"user signed up"

# Starts with
message:^"Started POST"

# Regex (if needed)
message:/error.*timeout/i
```

### Data (JSONB) Queries

```bash
# Dot notation for nested fields
data.user.id:123
data.order.status:failed
data.error.class:NoMethodError

# Numeric comparisons
data.duration_ms:>1000
data.order.total:>=100
data.retry_count:<3

# Array contains
data.tags:urgent
data.roles:admin
```

### Pipes & Commands

```bash
# Stats
level:error since:24h | stats

# Group by
level:error | stats by:commit
level:error | stats by:hour

# Count
env:production | count

# First/Last
commit:abc123 | first 10
commit:abc123 | last 10

# Sort
level:error | sort timestamp:asc
level:error | sort data.duration_ms:desc

# Fields (select specific fields)
level:error | fields timestamp,message,data.error
```

### Combining Queries

```bash
# AND (space separated)
level:error env:production since:1h

# OR (comma in value)
level:error,fatal

# Complex
level:error,fatal env:production commit:abc123 since:24h "payment" | stats by:hour
```

---

## Query Examples

### For Humans (Dashboard)

```bash
# What errors happened in the last hour?
level:error since:1h

# Show me errors from the latest deploy
level:error commit:abc123

# Find payment issues in production
"payment" level:error env:production

# What's happening on my feature branch?
branch:feature/add-auth since:1d

# Show me slow requests (> 1 second)
data.duration_ms:>1000 env:production

# Errors for a specific user
data.user.id:12345 level:error

# Full request trace
request_id:req-abc-123

# Stats by hour for the last day
level:error since:24h | stats by:hour

# Top errors by commit
level:error since:7d | stats by:commit | first 10
```

### For AI (MCP)

```python
@server.tool()
async def logs_query(query: str, limit: int = 100) -> dict:
    """
    Query logs using Brainz Query Language.
    
    Examples:
        "level:error since:1h"
        "commit:abc123 level:error,fatal"
        "data.user.id:123 env:production"
        '"payment failed" level:error | stats by:hour'
    
    Args:
        query: BQL query string
        limit: Max results (default 100)
    
    Returns:
        Matching logs or stats
    """
    return await api_query(query, limit)
```

AI uses the same query language:
```python
# AI debugging a deploy
await logs_query("level:error commit:abc123 since:30m")

# AI investigating user issue
await logs_query("data.user.id:456 level:error,warn since:24h")

# AI checking job failures
await logs_query("data.job.class:PaymentJob level:fatal since:1h")
```

---

## Parser Implementation

```ruby
# api/app/services/query_parser.rb

class QueryParser
  TOKENS = {
    field_value: /(\w+(?:\.\w+)*):(!)?([^\s]+)/,
    quoted_text: /"([^"]+)"/,
    time_relative: /(\d+)([mhdw])/,
    pipe: /\|/,
    command: /(stats|count|first|last|sort|fields)/,
  }
  
  def initialize(query)
    @query = query.strip
    @filters = {}
    @text_search = []
    @commands = []
  end
  
  def parse
    parts = split_by_pipe(@query)
    
    parse_filters(parts[0])
    parse_commands(parts[1..]) if parts.length > 1
    
    self
  end
  
  def to_scope(base_scope)
    scope = base_scope
    
    # Apply filters
    scope = apply_level(scope)
    scope = apply_environment(scope)
    scope = apply_commit(scope)
    scope = apply_branch(scope)
    scope = apply_service(scope)
    scope = apply_request_id(scope)
    scope = apply_session_id(scope)
    scope = apply_time_filters(scope)
    scope = apply_data_filters(scope)
    scope = apply_text_search(scope)
    
    # Apply commands
    scope = apply_commands(scope)
    
    scope
  end
  
  private
  
  def split_by_pipe(query)
    # Split by | but not inside quotes
    query.split(/\s*\|\s*(?=(?:[^"]*"[^"]*")*[^"]*$)/)
  end
  
  def parse_filters(filter_part)
    # Extract quoted text searches
    filter_part.scan(/"([^"]+)"/) do |match|
      @text_search << match[0]
    end
    
    # Remove quoted strings for field parsing
    remaining = filter_part.gsub(/"[^"]+"/, '')
    
    # Parse field:value pairs
    remaining.scan(/(\w+(?:\.\w+)*):(!)?([^\s]+)/) do |field, negation, value|
      @filters[field] = { value: value, negated: negation == '!' }
    end
  end
  
  def parse_commands(command_parts)
    command_parts.each do |part|
      tokens = part.strip.split(/\s+/)
      command = tokens[0]
      args = tokens[1..]
      
      @commands << { command: command, args: args }
    end
  end
  
  def apply_level(scope)
    return scope unless @filters['level']
    
    filter = @filters['level']
    levels = filter[:value].split(',')
    
    if filter[:negated]
      scope.where.not(level: levels)
    else
      scope.where(level: levels)
    end
  end
  
  def apply_environment(scope)
    return scope unless @filters['env'] || @filters['environment']
    
    filter = @filters['env'] || @filters['environment']
    envs = filter[:value].split(',')
    
    if filter[:negated]
      scope.where.not(environment: envs)
    else
      scope.where(environment: envs)
    end
  end
  
  def apply_commit(scope)
    return scope unless @filters['commit']
    scope.where(commit: @filters['commit'][:value])
  end
  
  def apply_branch(scope)
    return scope unless @filters['branch']
    scope.where(branch: @filters['branch'][:value])
  end
  
  def apply_service(scope)
    return scope unless @filters['service']
    scope.where(service: @filters['service'][:value])
  end
  
  def apply_request_id(scope)
    return scope unless @filters['request_id']
    scope.where(request_id: @filters['request_id'][:value])
  end
  
  def apply_session_id(scope)
    return scope unless @filters['session_id']
    scope.where(session_id: @filters['session_id'][:value])
  end
  
  def apply_time_filters(scope)
    if @filters['since']
      time = parse_time(@filters['since'][:value])
      scope = scope.where('timestamp >= ?', time)
    end
    
    if @filters['until']
      time = parse_time(@filters['until'][:value])
      scope = scope.where('timestamp <= ?', time)
    end
    
    scope
  end
  
  def parse_time(value)
    # Relative: 5m, 1h, 24h, 7d
    if value =~ /^(\d+)([mhdw])$/
      amount = $1.to_i
      unit = case $2
        when 'm' then :minutes
        when 'h' then :hours
        when 'd' then :days
        when 'w' then :weeks
      end
      amount.send(unit).ago
    else
      # Absolute: ISO8601
      Time.parse(value)
    end
  end
  
  def apply_data_filters(scope)
    @filters.each do |field, filter|
      next unless field.start_with?('data.')
      
      path = field.sub('data.', '').split('.')
      value = filter[:value]
      
      # Handle comparison operators
      if value =~ /^([><]=?)(.+)$/
        operator = $1
        val = $2
        
        # JSONB numeric comparison
        scope = scope.where(
          "CAST(data #>> ? AS NUMERIC) #{operator} ?",
          "{#{path.join(',')}}",
          val.to_f
        )
      else
        # Exact match
        scope = scope.where("data #>> ? = ?", "{#{path.join(',')}}", value)
      end
    end
    
    scope
  end
  
  def apply_text_search(scope)
    @text_search.each do |text|
      scope = scope.where("message ILIKE ?", "%#{text}%")
    end
    scope
  end
  
  def apply_commands(scope)
    @commands.each do |cmd|
      scope = case cmd[:command]
        when 'first' then scope.order(timestamp: :asc).limit(cmd[:args][0]&.to_i || 10)
        when 'last' then scope.order(timestamp: :desc).limit(cmd[:args][0]&.to_i || 10)
        when 'sort' then apply_sort(scope, cmd[:args])
        when 'stats' then apply_stats(scope, cmd[:args])
        when 'count' then scope # Will call .count later
        else scope
      end
    end
    
    scope
  end
  
  def apply_sort(scope, args)
    field, direction = args[0]&.split(':')
    direction ||= 'desc'
    
    if field&.start_with?('data.')
      path = field.sub('data.', '').split('.')
      scope.order(Arel.sql("data #>> '{#{path.join(',')}}' #{direction}"))
    else
      scope.order(field => direction.to_sym)
    end
  end
  
  def apply_stats(scope, args)
    # Returns a different result structure
    if args.include?('by:level')
      scope.group(:level).count
    elsif args.include?('by:commit')
      scope.group(:commit).count
    elsif args.include?('by:hour')
      scope.group_by_hour(:timestamp).count
    elsif args.include?('by:day')
      scope.group_by_day(:timestamp).count
    else
      {
        total: scope.count,
        by_level: scope.group(:level).count,
        by_environment: scope.group(:environment).count
      }
    end
  end
end
```

---

## API Controller

```ruby
# api/app/controllers/api/v1/logs_controller.rb

module Api
  module V1
    class LogsController < ApplicationController
      before_action :authenticate!
      
      # GET /api/v1/logs?q=level:error since:1h
      def index
        query = params[:q] || ""
        limit = (params[:limit] || 100).to_i.clamp(1, 1000)
        
        parser = QueryParser.new(query).parse
        scope = @project.log_entries
        result = parser.to_scope(scope)
        
        # Check if it's a stats query
        if result.is_a?(Hash)
          render json: { stats: result, query: query }
        else
          logs = result.limit(limit)
          render json: { 
            logs: logs, 
            count: logs.size,
            query: query 
          }
        end
      end
      
      # POST /api/v1/query (for complex queries)
      def query
        query = params[:query] || params[:q]
        limit = (params[:limit] || 100).to_i.clamp(1, 1000)
        
        parser = QueryParser.new(query).parse
        scope = @project.log_entries
        result = parser.to_scope(scope)
        
        if result.is_a?(Hash)
          render json: { stats: result, query: query }
        else
          logs = result.limit(limit)
          render json: { 
            logs: logs, 
            count: logs.size,
            query: query 
          }
        end
      end
    end
  end
end
```

---

## MCP Server

```python
# mcp/server.py

from mcp.server import Server
import httpx
import os

server = Server("brainz-logs")

API_URL = os.environ.get("LOGS_API_URL", "http://localhost:4001")
API_KEY = os.environ.get("LOGS_API_KEY")


async def query_logs(q: str, limit: int = 100) -> dict:
    """Execute a BQL query"""
    async with httpx.AsyncClient() as client:
        r = await client.get(
            f"{API_URL}/api/v1/logs",
            params={"q": q, "limit": limit},
            headers={"Authorization": f"Bearer {API_KEY}"}
        )
        return r.json()


@server.tool()
async def logs_query(query: str, limit: int = 100) -> dict:
    """
    Query logs using Brainz Query Language (BQL).
    
    Syntax: [text] [field:value]... [| command]
    
    Fields:
        level:error,warn,fatal     - Log level
        env:production             - Environment
        commit:abc123              - Git commit
        branch:main                - Git branch
        since:1h                   - Time (5m, 1h, 24h, 7d)
        until:30m                  - End time
        data.user.id:123           - Query JSON data
        request_id:xxx             - Request correlation
        session_id:yyy             - Session/job correlation
    
    Text search:
        "payment failed"           - Search in message
    
    Commands (after |):
        | stats                    - Get statistics
        | stats by:level           - Group by field
        | stats by:hour            - Group by time
        | first 10                 - First N results
        | last 10                  - Last N results
        | sort timestamp:asc       - Sort results
    
    Examples:
        level:error since:1h
        "payment" level:error env:production
        data.user.id:123 level:error,warn
        commit:abc123 | stats by:level
    
    Args:
        query: BQL query string
        limit: Max results (default 100)
    """
    return await query_logs(query, limit)


@server.tool()
async def logs_errors(since: str = "1h", commit: str = None) -> dict:
    """
    Shortcut: Get error logs.
    
    Args:
        since: Time range (default 1h)
        commit: Filter by commit (optional)
    """
    q = f"level:error,fatal since:{since}"
    if commit:
        q += f" commit:{commit}"
    return await query_logs(q)


@server.tool()
async def logs_by_commit(commit: str, level: str = None) -> dict:
    """
    Shortcut: Get logs for a specific commit.
    
    Args:
        commit: Git commit SHA
        level: Filter by level (optional)
    """
    q = f"commit:{commit}"
    if level:
        q += f" level:{level}"
    return await query_logs(q)


@server.tool()
async def logs_by_request(request_id: str) -> dict:
    """
    Shortcut: Get all logs for a request.
    
    Args:
        request_id: The request ID
    """
    return await query_logs(f"request_id:{request_id}", limit=500)


@server.tool()
async def logs_by_session(session_id: str) -> dict:
    """
    Shortcut: Get all logs for a session (job run, deploy, etc).
    
    Args:
        session_id: The session ID
    """
    return await query_logs(f"session_id:{session_id}", limit=500)


@server.tool()
async def logs_stats(since: str = "24h", by: str = None) -> dict:
    """
    Shortcut: Get log statistics.
    
    Args:
        since: Time range (default 24h)
        by: Group by field (level, commit, hour, day)
    """
    q = f"since:{since} | stats"
    if by:
        q += f" by:{by}"
    return await query_logs(q)


if __name__ == "__main__":
    import asyncio
    asyncio.run(server.run())
```

---

## Dashboard UI (React)

```tsx
// ui/src/components/QueryBar.tsx

import { useState } from 'react'

export function QueryBar({ onQuery }: { onQuery: (q: string) => void }) {
  const [query, setQuery] = useState('')
  
  const suggestions = [
    { label: 'Errors (1h)', query: 'level:error since:1h' },
    { label: 'Production errors', query: 'level:error env:production since:24h' },
    { label: 'By commit', query: 'commit:' },
    { label: 'By user', query: 'data.user.id:' },
    { label: 'Stats by level', query: 'since:24h | stats by:level' },
  ]
  
  return (
    <div className="query-bar">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onKeyDown={(e) => e.key === 'Enter' && onQuery(query)}
        placeholder='level:error since:1h "payment"'
        className="query-input"
      />
      <button onClick={() => onQuery(query)}>Search</button>
      
      <div className="suggestions">
        {suggestions.map(s => (
          <button 
            key={s.label} 
            onClick={() => { setQuery(s.query); onQuery(s.query) }}
          >
            {s.label}
          </button>
        ))}
      </div>
    </div>
  )
}

// ui/src/components/LogViewer.tsx

export function LogViewer({ logs }: { logs: LogEntry[] }) {
  return (
    <div className="log-viewer">
      {logs.map(log => (
        <LogRow key={log.id} log={log} />
      ))}
    </div>
  )
}

function LogRow({ log }: { log: LogEntry }) {
  const [expanded, setExpanded] = useState(false)
  
  return (
    <div className={`log-row level-${log.level}`} onClick={() => setExpanded(!expanded)}>
      <span className="timestamp">{formatTime(log.timestamp)}</span>
      <span className={`level ${log.level}`}>{log.level.toUpperCase()}</span>
      <span className="message">{log.message}</span>
      <span className="meta">
        {log.commit && <span className="commit">{log.commit.slice(0, 7)}</span>}
        {log.environment && <span className="env">{log.environment}</span>}
      </span>
      
      {expanded && (
        <div className="log-details">
          <pre>{JSON.stringify(log.data, null, 2)}</pre>
          <div className="log-meta">
            <span>Request: {log.request_id}</span>
            <span>Branch: {log.branch}</span>
            <span>Service: {log.service}</span>
            <span>Host: {log.host}</span>
          </div>
        </div>
      )}
    </div>
  )
}
```

---

## Query Language Reference

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BRAINZ QUERY LANGUAGE (BQL)                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SYNTAX                                                                      │
│  ──────                                                                      │
│  [text search] [field:value]... [| command]                                 │
│                                                                              │
│                                                                              │
│  FIELDS                                                                      │
│  ──────                                                                      │
│  level:error           Level: debug, info, warn, error, fatal               │
│  level:error,warn      Multiple values (OR)                                 │
│  level:!debug          Negation                                             │
│                                                                              │
│  env:production        Environment                                          │
│  commit:abc123         Git commit SHA                                       │
│  branch:main           Git branch                                           │
│  service:api           Service name                                         │
│  host:web-1            Hostname                                             │
│                                                                              │
│  request_id:xxx        Request correlation                                  │
│  session_id:yyy        Session/job correlation                              │
│                                                                              │
│                                                                              │
│  TIME                                                                        │
│  ────                                                                        │
│  since:5m              Last 5 minutes                                       │
│  since:1h              Last 1 hour                                          │
│  since:24h             Last 24 hours                                        │
│  since:7d              Last 7 days                                          │
│  until:1h              Before 1 hour ago                                    │
│  since:2024-01-15      Absolute date                                        │
│                                                                              │
│                                                                              │
│  DATA (JSONB)                                                                │
│  ────────────                                                                │
│  data.user.id:123           Exact match                                     │
│  data.order.total:>100      Greater than                                    │
│  data.duration_ms:>=1000    Greater or equal                                │
│  data.retry:<3              Less than                                       │
│                                                                              │
│                                                                              │
│  TEXT SEARCH                                                                 │
│  ───────────                                                                 │
│  "payment failed"      Contains text                                        │
│  "Started POST"        Phrase search                                        │
│                                                                              │
│                                                                              │
│  COMMANDS (after |)                                                          │
│  ──────────────────                                                          │
│  | stats               Overall statistics                                   │
│  | stats by:level      Group by level                                       │
│  | stats by:commit     Group by commit                                      │
│  | stats by:hour       Group by hour                                        │
│  | stats by:day        Group by day                                         │
│  | first 10            First N results (oldest)                             │
│  | last 10             Last N results (newest)                              │
│  | sort timestamp:asc  Sort ascending                                       │
│  | sort data.ms:desc   Sort by JSON field                                   │
│  | count               Just count                                           │
│                                                                              │
│                                                                              │
│  EXAMPLES                                                                    │
│  ────────                                                                    │
│  level:error since:1h                                                       │
│  "payment" level:error env:production                                       │
│  data.user.id:123 level:error,warn since:24h                                │
│  commit:abc123 | stats by:level                                             │
│  env:production since:7d | stats by:day                                     │
│  data.duration_ms:>1000 | sort data.duration_ms:desc | first 20             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Summary

### Why a DSL?

1. **Same language everywhere** - Dashboard, API, MCP, CLI
2. **Learnable** - SQL-like, intuitive
3. **Powerful** - Filters, JSONB queries, pipes, stats
4. **AI-friendly** - Easy to generate, easy to explain

### Architecture Decision: Postgres Only (for now)

Start with Postgres + JSONB + pg_trgm. Add OpenSearch later if:
- Text search becomes a bottleneck
- Need more complex aggregations
- Scale requires it

The DSL abstracts the backend - you can swap Postgres for OpenSearch without changing the query language.

---

*Document Version: 3.0 - With Query DSL*
