require "rails_helper"

RSpec.describe "Api::V1::Logs", type: :request, timescaledb: true do
  let(:project) { create(:project) }
  let(:headers) { auth_headers(project) }

  describe "GET /api/v1/logs" do
    let!(:error_entry) { create(:log_entry, :error, project: project, timestamp: 1.hour.ago) }
    let!(:warn_entry)  { create(:log_entry, :warn,  project: project, timestamp: 30.minutes.ago) }
    let!(:info_entry)  { create(:log_entry, :info,  project: project, timestamp: 10.minutes.ago) }

    it "returns all project logs when no query given" do
      get "/api/v1/logs", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["count"]).to eq(3)
    end

    it "filters logs with the DSL query" do
      get "/api/v1/logs", params: { q: "level:error" }, headers: headers
      body = JSON.parse(response.body)
      expect(body["count"]).to eq(1)
      expect(body["logs"].first["level"]).to eq("error")
    end

    it "returns the parsed query in the response" do
      get "/api/v1/logs", params: { q: "level:warn" }, headers: headers
      body = JSON.parse(response.body)
      expect(body["query"]).to eq("level:warn")
    end

    it "respects the limit param" do
      get "/api/v1/logs", params: { limit: 1 }, headers: headers
      body = JSON.parse(response.body)
      expect(body["logs"].size).to eq(1)
    end

    it "returns stats when query contains | stats by:level" do
      get "/api/v1/logs", params: { q: "| stats by:level" }, headers: headers
      body = JSON.parse(response.body)
      expect(body).to have_key("stats")
      expect(body["stats"]["error"]).to eq(1)
    end

    it "does not return logs from other projects" do
      other_project = create(:project)
      create(:log_entry, :error, project: other_project)

      get "/api/v1/logs", params: { q: "level:error" }, headers: headers
      body = JSON.parse(response.body)
      expect(body["count"]).to eq(1)
    end

    context "without authentication" do
      it "returns 401" do
        get "/api/v1/logs"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/logs/:id" do
    let!(:entry) { create(:log_entry, project: project) }

    it "returns the log entry by composite key" do
      get "/api/v1/logs/#{entry.composite_key}", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(entry.id)
    end

    it "returns 404 for an unknown composite key" do
      fake_key = "00000000-0000-0000-0000-000000000000_2025-01-01T00:00:00.000000+00:00"
      get "/api/v1/logs/#{fake_key}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an invalid key format" do
      get "/api/v1/logs/not-a-valid-key", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "does not return entries from other projects" do
      other_project = create(:project)
      other_entry   = create(:log_entry, project: other_project)

      get "/api/v1/logs/#{other_entry.composite_key}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/logs/export" do
    before { create_list(:log_entry, 3, project: project) }

    it "returns a JSON export file" do
      get "/api/v1/logs/export", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end

    it "returns a CSV export when format=csv" do
      get "/api/v1/logs/export", params: { format: "csv" }, headers: headers
      expect(response.content_type).to include("text/csv")
    end

    it "defaults to JSON for unknown format" do
      get "/api/v1/logs/export", params: { format: "xml" }, headers: headers
      expect(response.content_type).to include("application/json")
    end

    it "respects query filter in export" do
      create(:log_entry, :fatal, project: project)
      get "/api/v1/logs/export", params: { q: "level:fatal", format: "json" }, headers: headers
      data = JSON.parse(response.body)
      expect(data.size).to eq(1)
      expect(data.first["level"]).to eq("fatal")
    end
  end

  describe "GET /api/v1/logs/query (Signal integration)" do
    before do
      create(:log_entry, :error, project: project, service: "web", timestamp: 2.minutes.ago)
      create(:log_entry, :error, project: project, service: "worker", timestamp: 3.minutes.ago)
      create(:log_entry, :info,  project: project, service: "web", timestamp: 1.minute.ago)
    end

    it "returns count of matching log level in time window" do
      get "/api/v1/logs/query",
          params: { log_level: "error", window: "5m" },
          headers: headers

      body = JSON.parse(response.body)
      expect(body["value"]).to eq(2)
      expect(body["log_level"]).to eq("error")
    end

    it "applies service filter from query JSON" do
      get "/api/v1/logs/query",
          params: { log_level: "error", window: "5m", query: { service: "web" }.to_json },
          headers: headers

      body = JSON.parse(response.body)
      expect(body["value"]).to eq(1)
    end

    it "defaults to error level" do
      get "/api/v1/logs/query", params: { window: "5m" }, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/logs/baseline (Signal integration)" do
    before do
      create(:log_entry, :error, project: project, timestamp: 30.minutes.ago)
      create(:log_entry, :error, project: project, timestamp: 90.minutes.ago)
      create(:log_entry, :error, project: project, timestamp: 2.hours.ago)
    end

    it "returns mean and stddev" do
      get "/api/v1/logs/baseline",
          params: { log_level: "error", window: "3h" },
          headers: headers

      body = JSON.parse(response.body)
      expect(body).to have_key("mean")
      expect(body).to have_key("stddev")
      expect(body["mean"]).to be > 0
      expect(body["stddev"]).to be >= 1
    end

    it "returns mean:0, stddev:1 when no logs found" do
      get "/api/v1/logs/baseline",
          params: { log_level: "fatal", window: "1m" },
          headers: headers

      body = JSON.parse(response.body)
      expect(body["mean"]).to eq(0)
      expect(body["stddev"]).to eq(1)
    end
  end

  describe "GET /api/v1/logs/last (Signal integration)" do
    let!(:last_entry) { create(:log_entry, :error, project: project, timestamp: 5.minutes.ago) }

    it "returns the last matching log entry" do
      get "/api/v1/logs/last", params: { log_level: "error" }, headers: headers

      body = JSON.parse(response.body)
      expect(body["timestamp"]).to be_present
      expect(body["value"]).to eq(1)
    end

    it "returns nil timestamp when no matching entries" do
      get "/api/v1/logs/last", params: { log_level: "fatal" }, headers: headers

      body = JSON.parse(response.body)
      expect(body["timestamp"]).to be_nil
      expect(body["value"]).to be_nil
    end
  end
end
