require "rails_helper"

RSpec.describe "Dashboard::Exports", type: :request, timescaledb: true do
  let(:project) { create(:project) }

  before do
    create_list(:log_entry, 3, project: project)
  end

  describe "POST /dashboard/projects/:project_id/exports" do
    it "exports logs as JSON by default" do
      post dashboard_project_exports_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end

    it "exports logs as CSV when format=csv" do
      post dashboard_project_exports_path(project), params: { format: "csv" }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
    end

    it "defaults to JSON for unknown format" do
      post dashboard_project_exports_path(project), params: { format: "xml" }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
    end

    it "applies query filter" do
      create(:log_entry, :fatal, project: project)
      post dashboard_project_exports_path(project), params: { q: "level:fatal", format: "json" }
      data = JSON.parse(response.body)
      expect(data.size).to eq(1)
    end
  end
end
