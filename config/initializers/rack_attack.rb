# config/initializers/rack_attack.rb
#
# Rack::Attack rate limiting for Recall service.
# S-08: Protects ingest, read, SSO callback, MCP, and dashboard endpoints.

# Use a dedicated MemoryStore to avoid eviction interference from Rails.cache
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

# ---------------------------------------------------------------------------
# Safelists
# ---------------------------------------------------------------------------

# Allow localhost in development and test environments
if Rails.env.development? || Rails.env.test?
  Rack::Attack.safelist("allow localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Extracts the API key from Authorization: Bearer <key> or X-API-Key header.
# Returns nil when neither header is present (falls back to IP-based limiting).
API_KEY_EXTRACTOR = ->(req) {
  req.env["HTTP_AUTHORIZATION"]&.sub(/^Bearer\s+/, "") ||
    req.env["HTTP_X_API_KEY"]
}

# ---------------------------------------------------------------------------
# Throttles
# ---------------------------------------------------------------------------

# API Ingest — POST /api/v1/log and POST /api/v1/logs
# Highest-traffic endpoints; strict per-key limit to protect ingestion pipeline.
Rack::Attack.throttle("api/ingest", limit: 300, period: 60.seconds) do |req|
  if req.post? && req.path.match?(%r{\A/api/v1/logs?\z})
    API_KEY_EXTRACTOR.call(req) || req.ip
  end
end

# API Read — GET /api/v1/logs, /api/v1/sessions, etc.
Rack::Attack.throttle("api/read", limit: 120, period: 60.seconds) do |req|
  if req.get? && req.path.start_with?("/api/v1/")
    API_KEY_EXTRACTOR.call(req) || req.ip
  end
end

# SSO Callback — brute-force protection, IP-based
Rack::Attack.throttle("sso/callback", limit: 10, period: 60.seconds) do |req|
  req.ip if req.get? && req.path == "/sso/callback"
end

# MCP Server — POST /mcp/rpc
Rack::Attack.throttle("mcp/rpc", limit: 60, period: 60.seconds) do |req|
  if req.post? && req.path == "/mcp/rpc"
    API_KEY_EXTRACTOR.call(req) || req.ip
  end
end

# Dashboard — session-based users identified by IP
Rack::Attack.throttle("dashboard", limit: 120, period: 60.seconds) do |req|
  req.ip if req.path.start_with?("/dashboard/")
end

# ---------------------------------------------------------------------------
# Custom 429 response
# ---------------------------------------------------------------------------

Rack::Attack.throttled_responder = lambda do |req|
  match_data = req.env["rack.attack.match_data"]
  retry_after = match_data ? (match_data[:period] - (Time.now.to_i % match_data[:period])) : 60

  [
    429,
    {
      "Content-Type" => "application/json",
      "Retry-After" => retry_after.to_s
    },
    [ { error: "Rate limit exceeded. Retry after #{retry_after} seconds." }.to_json ]
  ]
end
