require "rails_helper"

RSpec.describe "Api::V1::Browser", type: :request, timescaledb: true do
  let(:project) { create(:project) }

  describe "OPTIONS /api/v1/browser (preflight)" do
    it "returns 200 with CORS headers" do
      process(:options, "/api/v1/browser")
      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Allow-Methods"]).to include("POST")
    end
  end

  describe "POST /api/v1/browser" do
    let(:console_event) do
      {
        type: "console",
        url: "https://myapp.com/dashboard",
        timestamp: Time.current.iso8601,
        sessionId: "sess-browser-123",
        data: {
          level: "error",
          message: "Uncaught TypeError: Cannot read property",
          args: ["error details"]
        }
      }
    end

    context "with valid ingest key" do
      it "accepts console events and creates log entries" do
        expect {
          post "/api/v1/browser",
               params: { events: [console_event], context: { environment: "production" } },
               headers: { "Authorization" => "Bearer #{project.ingest_key}" }
        }.to change(LogEntry, :count).by(1)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["accepted"]).to eq(1)
        expect(body["status"]).to eq("ok")
      end

      it "maps console levels correctly" do
        %w[error warn info debug].each do |level|
          event = console_event.deep_merge(data: { level: level })
          post "/api/v1/browser",
               params: { events: [event], context: {} },
               headers: { "Authorization" => "Bearer #{project.ingest_key}" }
        end

        levels = LogEntry.where(project: project).pluck(:level)
        expect(levels).to include("error", "warn", "info", "debug")
      end

      it "stores browser source in data" do
        post "/api/v1/browser",
             params: { events: [console_event], context: {} },
             headers: { "Authorization" => "Bearer #{project.ingest_key}" }

        entry = LogEntry.order(timestamp: :desc).first
        expect(entry.data["source"]).to eq("browser")
        expect(entry.data["url"]).to eq("https://myapp.com/dashboard")
      end

      it "ignores non-console events" do
        non_console = { type: "navigation", url: "/page" }
        expect {
          post "/api/v1/browser",
               params: { events: [non_console], context: {} },
               headers: { "Authorization" => "Bearer #{project.ingest_key}" }
        }.not_to change(LogEntry, :count)

        body = JSON.parse(response.body)
        expect(body["accepted"]).to eq(0)
      end

      # Empty array via form params gets coerced to [""] by Rails,
      # which causes the controller rescue to return 422.
      it "returns 422 for empty events array due to form param coercion" do
        post "/api/v1/browser",
             params: { events: [], context: {} },
             headers: { "Authorization" => "Bearer #{project.ingest_key}" }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "includes CORS headers in response" do
        post "/api/v1/browser",
             params: { events: [console_event], context: {} },
             headers: { "Authorization" => "Bearer #{project.ingest_key}" }

        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      end
    end

    context "with API key" do
      it "also accepts rcl_api_ keys" do
        expect {
          post "/api/v1/browser",
               params: { events: [console_event], context: {} },
               headers: { "Authorization" => "Bearer #{project.api_key}" }
        }.to change(LogEntry, :count).by(1)
      end
    end

    context "without authentication" do
      it "returns 401" do
        post "/api/v1/browser",
             params: { events: [console_event], context: {} }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with sk_live_ key (Platform key)" do
      it "rejects browser-side Platform keys for security" do
        post "/api/v1/browser",
             params: { events: [console_event], context: {} },
             headers: { "Authorization" => "Bearer sk_live_test123" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with W3C traceparent header" do
      it "extracts trace context from traceparent" do
        traceparent = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
        post "/api/v1/browser",
             params: { events: [console_event], context: {} },
             headers: {
               "Authorization" => "Bearer #{project.ingest_key}",
               "traceparent" => traceparent
             }

        entry = LogEntry.order(timestamp: :desc).first
        expect(entry.data["trace_id"]).to eq("0af7651916cd43dd8448eb211c80319c")
      end
    end
  end
end
