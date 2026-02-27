require "rails_helper"

RSpec.describe "Api::V1::Projects", type: :request do
  let(:master_key)  { "test_master_key_recall" }
  let(:master_hdrs) { { "X-Master-Key" => master_key } }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("RECALL_MASTER_KEY").and_return(master_key)
  end

  describe "POST /api/v1/projects/provision" do
    context "with Platform project_id" do
      let(:params) { { platform_project_id: SecureRandom.uuid, name: "My App", environment: "production" } }

      it "creates a new project and returns keys" do
        expect {
          post "/api/v1/projects/provision", params: params, headers: master_hdrs
        }.to change(Project, :count).by(1)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["ingest_key"]).to be_present
        expect(body["api_key"]).to be_present
        expect(body["slug"]).to be_present
        expect(body["environment"]).to eq("production")
      end

      it "is idempotent — returns existing project on repeat call" do
        post "/api/v1/projects/provision", params: params, headers: master_hdrs
        expect {
          post "/api/v1/projects/provision", params: params, headers: master_hdrs
        }.not_to change(Project, :count)

        expect(response).to have_http_status(:ok)
      end

      it "updates the project name on repeat call" do
        post "/api/v1/projects/provision", params: params, headers: master_hdrs
        updated_params = params.merge(name: "New Name")
        post "/api/v1/projects/provision", params: updated_params, headers: master_hdrs

        project = Project.find_by(platform_project_id: params[:platform_project_id])
        expect(project.name).to eq("New Name")
      end
    end

    context "in standalone mode (name only, no platform_project_id)" do
      let(:params) { { name: "Standalone App" } }

      it "creates a project by name" do
        expect {
          post "/api/v1/projects/provision", params: params, headers: master_hdrs
        }.to change(Project, :count).by(1)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["name"]).to eq("Standalone App")
      end

      it "is idempotent" do
        post "/api/v1/projects/provision", params: params, headers: master_hdrs
        expect {
          post "/api/v1/projects/provision", params: params, headers: master_hdrs
        }.not_to change(Project, :count)
      end
    end

    context "with neither platform_project_id nor name" do
      it "returns 400 Bad Request" do
        post "/api/v1/projects/provision", params: {}, headers: master_hdrs
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "without master key" do
      it "returns 401 Unauthorized" do
        post "/api/v1/projects/provision", params: { name: "App" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 for a wrong master key" do
        post "/api/v1/projects/provision",
             params: { name: "App" },
             headers: { "X-Master-Key" => "wrong_key" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/projects/lookup" do
    let!(:project) { create(:project, name: "Lookup App") }

    context "by name" do
      it "returns the project" do
        get "/api/v1/projects/lookup", params: { name: "Lookup App" }, headers: master_hdrs
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["name"]).to eq("Lookup App")
        expect(body["ingest_key"]).to eq(project.ingest_key)
        expect(body["api_key"]).to eq(project.api_key)
      end
    end

    context "by slug" do
      it "returns the project when searching by slug value" do
        get "/api/v1/projects/lookup", params: { name: project.slug }, headers: master_hdrs
        expect(response).to have_http_status(:ok)
      end
    end

    context "by platform_project_id" do
      let!(:platform_project) { create(:project, :with_platform) }

      it "returns the project" do
        get "/api/v1/projects/lookup",
            params: { platform_project_id: platform_project.platform_project_id },
            headers: master_hdrs
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["platform_project_id"]).to eq(platform_project.platform_project_id)
      end
    end

    context "when project not found" do
      it "returns 404" do
        get "/api/v1/projects/lookup", params: { name: "nonexistent" }, headers: master_hdrs
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)["error"]).to eq("Project not found")
      end
    end

    context "without master key" do
      it "returns 401" do
        get "/api/v1/projects/lookup", params: { name: "Lookup App" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
