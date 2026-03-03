require "rails_helper"

RSpec.describe "Mcp::Tools", type: :request, timescaledb: true do
  let(:project) { create(:project) }
  let(:headers) { { "Authorization" => "Bearer #{project.api_key}" } }

  describe "GET /mcp/tools" do
    it "returns list of available tools" do
      get "/mcp/tools", headers: headers
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["tools"]).to be_an(Array)
      expect(body["tools"].size).to eq(7)

      tool_names = body["tools"].map { |t| t["name"] }
      expect(tool_names).to include("recall_query", "recall_errors", "recall_stats")
    end

    context "without authentication" do
      it "returns 401" do
        get "/mcp/tools"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /mcp/tools/:name" do
    it "calls a tool and returns result" do
      create(:log_entry, :error, project: project)

      post "/mcp/tools/recall_errors", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "returns 422 for an unknown tool" do
      post "/mcp/tools/unknown_tool", headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error"]).to include("Unknown tool")
    end
  end

  describe "POST /mcp/rpc" do
    it "handles initialize method" do
      post "/mcp/rpc",
           params: { method: "initialize", id: 1 },
           headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["jsonrpc"]).to eq("2.0")
      expect(body["result"]["protocolVersion"]).to eq("2024-11-05")
      expect(body["result"]["serverInfo"]["name"]).to eq("recall")
    end

    it "handles ping method" do
      post "/mcp/rpc",
           params: { method: "ping", id: 2 },
           headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["result"]).to eq({})
    end

    it "handles notifications/initialized method" do
      post "/mcp/rpc",
           params: { method: "notifications/initialized", id: 3 },
           headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "handles tools/list method" do
      post "/mcp/rpc",
           params: { method: "tools/list", id: 4 },
           headers: headers

      body = JSON.parse(response.body)
      expect(body["result"]["tools"]).to be_an(Array)
    end

    it "handles tools/call method" do
      create(:log_entry, :error, project: project)

      post "/mcp/rpc",
           params: {
             method: "tools/call",
             id: 5,
             params: { name: "recall_stats" }
           },
           headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["result"]["content"]).to be_an(Array)
    end

    it "returns error for unknown method" do
      post "/mcp/rpc",
           params: { method: "unknown/method", id: 99 },
           headers: headers

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body["error"]["code"]).to eq(-32601)
    end

    context "without authentication" do
      it "returns 401" do
        post "/mcp/rpc", params: { method: "ping", id: 1 }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
