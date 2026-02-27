require "rails_helper"

RSpec.describe "Api::V1::Ingest", type: :request, timescaledb: true do
  let(:project) { create(:project) }

  describe "POST /api/v1/log" do
    context "with valid ingest key" do
      it "creates a log entry and returns 201" do
        expect {
          post "/api/v1/log",
               params: { level: "info", message: "App started" },
               headers: ingest_headers(project)
        }.to change(LogEntry, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to have_key("id")
      end

      it "creates a log entry with the api_key as well" do
        expect {
          post "/api/v1/log",
               params: { level: "warn", message: "High memory" },
               headers: auth_headers(project)
        }.to change(LogEntry, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it "defaults timestamp to now when not provided" do
        Timecop.freeze do
          post "/api/v1/log",
               params: { level: "info", message: "Test" },
               headers: ingest_headers(project)

          entry = LogEntry.order(timestamp: :desc).first
          expect(entry.timestamp).to be_within(2.seconds).of(Time.current)
        end
      end

      it "stores the provided timestamp" do
        ts = 2.hours.ago.iso8601
        post "/api/v1/log",
             params: { level: "error", message: "Old error", timestamp: ts },
             headers: ingest_headers(project)

        entry = LogEntry.order(timestamp: :desc).first
        expect(entry.timestamp).to be_within(2.seconds).of(Time.parse(ts))
      end

      it "stores structured data in the data JSONB field" do
        post "/api/v1/log",
             params: { level: "info", message: "Checkout", data: { user_id: 42, amount: 99.99 } },
             headers: ingest_headers(project)

        entry = LogEntry.order(timestamp: :desc).first
        expect(entry.data["user_id"]).to eq(42)
      end

      it "associates the log with the correct project" do
        other_project = create(:project)
        post "/api/v1/log",
             params: { level: "info", message: "Test" },
             headers: ingest_headers(project)

        entry = LogEntry.order(timestamp: :desc).first
        expect(entry.project_id).to eq(project.id)
      end
    end

    context "with Bearer token header" do
      it "accepts Authorization: Bearer <key>" do
        expect {
          post "/api/v1/log",
               params: { level: "info", message: "Bearer auth test" },
               headers: { "Authorization" => "Bearer #{project.ingest_key}" }
        }.to change(LogEntry, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end

    context "with X-API-Key header" do
      it "accepts X-API-Key header" do
        expect {
          post "/api/v1/log",
               params: { level: "info", message: "API Key auth test" },
               headers: { "X-API-Key" => project.ingest_key }
        }.to change(LogEntry, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end

    context "without authentication" do
      it "returns 401 Unauthorized" do
        post "/api/v1/log", params: { level: "info", message: "Test" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 for a wrong key" do
        post "/api/v1/log",
             params: { level: "info", message: "Test" },
             headers: { "Authorization" => "Bearer wrong_key_000" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/logs (batch)" do
    context "with valid authentication" do
      let(:logs_payload) do
        [
          { level: "info",  message: "Request start", timestamp: 2.minutes.ago.iso8601 },
          { level: "error", message: "DB timeout",    timestamp: 1.minute.ago.iso8601 },
          { level: "warn",  message: "Slow query",    timestamp: Time.current.iso8601 }
        ]
      end

      it "ingests multiple logs and returns 201" do
        expect {
          post "/api/v1/logs",
               params: { logs: logs_payload },
               headers: ingest_headers(project)
        }.to change(LogEntry, :count).by(3)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["ingested"]).to eq(3)
      end

      it "handles an empty logs array gracefully" do
        post "/api/v1/logs",
             params: { logs: [] },
             headers: ingest_headers(project)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["ingested"]).to eq(0)
      end

      it "returns 0 ingested when logs param is missing" do
        post "/api/v1/logs",
             params: {},
             headers: ingest_headers(project)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["ingested"]).to eq(0)
      end
    end

    context "without authentication" do
      it "returns 401" do
        post "/api/v1/logs", params: { logs: [ { level: "info", message: "Test" } ] }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
