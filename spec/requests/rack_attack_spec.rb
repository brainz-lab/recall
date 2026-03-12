require "rails_helper"

RSpec.describe "Rack::Attack rate limiting", type: :request do
  let(:project) { create(:project) }

  # -------------------------------------------------------------------------
  # Setup: disable the localhost safelist so throttling actually fires in test,
  # and replace each throttle with a low limit (2 req/period) for fast tests.
  # -------------------------------------------------------------------------
  before do
    # Use a real MemoryStore for rack-attack so counters work (Rails.cache is NullStore in test)
    @original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.safelists.clear

    # Re-define every throttle with limit: 2 to avoid looping hundreds of times.
    {
      "api/ingest" => ->(req) {
        if req.post? && req.path.match?(%r{\A/api/v1/logs?\z})
          req.env["HTTP_AUTHORIZATION"]&.sub(/^Bearer\s+/, "") || req.env["HTTP_X_API_KEY"] || req.ip
        end
      },
      "api/read" => ->(req) {
        if req.get? && req.path.start_with?("/api/v1/")
          req.env["HTTP_AUTHORIZATION"]&.sub(/^Bearer\s+/, "") || req.env["HTTP_X_API_KEY"] || req.ip
        end
      },
      "sso/callback" => ->(req) {
        req.ip if req.get? && req.path == "/sso/callback"
      },
      "mcp/rpc" => ->(req) {
        if req.post? && req.path == "/mcp/rpc"
          req.env["HTTP_AUTHORIZATION"]&.sub(/^Bearer\s+/, "") || req.env["HTTP_X_API_KEY"] || req.ip
        end
      },
      "dashboard" => ->(req) {
        req.ip if req.path.start_with?("/dashboard/")
      }
    }.each do |name, block|
      Rack::Attack.throttles.delete(name)
      Rack::Attack.throttle(name, limit: 2, period: 60.seconds, &block)
    end
  end

  after do
    # Restore the original initializer so other specs are unaffected.
    Rack::Attack.clear_configuration
    Rack::Attack.cache.store = @original_store
    load Rails.root.join("config/initializers/rack_attack.rb")
  end

  # -------------------------------------------------------------------------
  # Helpers
  # -------------------------------------------------------------------------

  def parsed_body
    JSON.parse(response.body)
  end

  # -------------------------------------------------------------------------
  # API Ingest — POST /api/v1/log and POST /api/v1/logs
  # -------------------------------------------------------------------------
  describe "api/ingest throttle" do
    it "allows requests within the limit" do
      2.times do
        post "/api/v1/log",
             params: { level: "info", message: "ok" },
             headers: ingest_headers(project)
      end

      expect(response).to have_http_status(:created)
    end

    it "returns 429 after exceeding the limit on POST /api/v1/log" do
      3.times do
        post "/api/v1/log",
             params: { level: "info", message: "burst" },
             headers: ingest_headers(project)
      end

      expect(response).to have_http_status(:too_many_requests)
      expect(parsed_body["error"]).to match(/Rate limit exceeded/)
      expect(response.headers["Retry-After"]).to be_present
    end

    it "returns 429 after exceeding the limit on POST /api/v1/logs" do
      3.times do
        post "/api/v1/logs",
             params: { logs: [ { level: "info", message: "batch" } ] },
             headers: ingest_headers(project)
      end

      expect(response).to have_http_status(:too_many_requests)
    end

    it "tracks ingest keys independently" do
      other_project = create(:project)

      2.times do
        post "/api/v1/log",
             params: { level: "info", message: "p1" },
             headers: ingest_headers(project)
      end
      expect(response).to have_http_status(:created)

      # Different key should have its own counter
      post "/api/v1/log",
           params: { level: "info", message: "p2" },
           headers: ingest_headers(other_project)

      expect(response).to have_http_status(:created)
    end
  end

  # -------------------------------------------------------------------------
  # API Read — GET /api/v1/*
  # -------------------------------------------------------------------------
  describe "api/read throttle" do
    it "allows requests within the limit" do
      2.times { get "/api/v1/logs", headers: auth_headers(project) }

      expect(response).to have_http_status(:ok)
    end

    it "returns 429 after exceeding the limit on GET /api/v1/logs" do
      3.times { get "/api/v1/logs", headers: auth_headers(project) }

      expect(response).to have_http_status(:too_many_requests)
      expect(parsed_body["error"]).to match(/Rate limit exceeded/)
      expect(response.headers["Retry-After"]).to be_present
    end

    it "tracks API keys independently" do
      other_project = create(:project)

      2.times { get "/api/v1/logs", headers: auth_headers(project) }
      expect(response).to have_http_status(:ok)

      get "/api/v1/logs", headers: auth_headers(other_project)
      expect(response).to have_http_status(:ok)
    end
  end

  # -------------------------------------------------------------------------
  # SSO Callback — GET /sso/callback
  # -------------------------------------------------------------------------
  describe "sso/callback throttle" do
    let(:platform_internal_url) { ENV.fetch("BRAINZLAB_PLATFORM_URL", "http://platform:3000") }

    before do
      # SSO callback calls Platform; stub it so the request doesn't fail from WebMock.
      stub_request(:post, "#{platform_internal_url}/api/v1/sso/validate")
        .to_return(status: 401, body: { error: "Invalid" }.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "allows requests within the limit" do
      2.times { get "/sso/callback", params: { token: "tok" } }

      # Even invalid SSO tokens go through Rack::Attack; the app returns a redirect.
      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "returns 429 after exceeding the limit" do
      3.times { get "/sso/callback", params: { token: "tok" } }

      expect(response).to have_http_status(:too_many_requests)
      expect(parsed_body["error"]).to match(/Rate limit exceeded/)
      expect(response.headers["Retry-After"]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # MCP RPC — POST /mcp/rpc
  # -------------------------------------------------------------------------
  describe "mcp/rpc throttle" do
    it "allows requests within the limit" do
      2.times do
        post "/mcp/rpc",
             params: { method: "ping", id: 1 },
             headers: auth_headers(project)
      end

      expect(response).to have_http_status(:ok)
    end

    it "returns 429 after exceeding the limit" do
      3.times do
        post "/mcp/rpc",
             params: { method: "ping", id: 1 },
             headers: auth_headers(project)
      end

      expect(response).to have_http_status(:too_many_requests)
      expect(parsed_body["error"]).to match(/Rate limit exceeded/)
      expect(response.headers["Retry-After"]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # Dashboard — /dashboard/*
  # -------------------------------------------------------------------------
  describe "dashboard throttle" do
    it "returns 429 after exceeding the limit" do
      3.times { get "/dashboard/projects" }

      expect(response).to have_http_status(:too_many_requests)
      expect(parsed_body["error"]).to match(/Rate limit exceeded/)
    end
  end

  # -------------------------------------------------------------------------
  # 429 response format
  # -------------------------------------------------------------------------
  describe "throttled response format" do
    it "returns JSON content type" do
      3.times do
        post "/api/v1/log",
             params: { level: "info", message: "fmt" },
             headers: ingest_headers(project)
      end

      expect(response.content_type).to include("application/json")
    end

    it "includes Retry-After header with a positive integer" do
      3.times do
        post "/api/v1/log",
             params: { level: "info", message: "retry" },
             headers: ingest_headers(project)
      end

      retry_after = response.headers["Retry-After"].to_i
      expect(retry_after).to be_between(1, 60)
    end

    it "includes a human-readable error message with retry seconds" do
      3.times do
        post "/api/v1/log",
             params: { level: "info", message: "msg" },
             headers: ingest_headers(project)
      end

      expect(parsed_body["error"]).to match(/Retry after \d+ seconds/)
    end
  end
end
