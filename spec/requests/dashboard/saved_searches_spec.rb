require "rails_helper"

# BUG: Dashboard layout has ERB syntax error (extra <% end %> on line 114).
# HTML rendering returns 500. JSON and redirect actions still work.
# See QA_BUG_REPORT.md BUG-004.
RSpec.describe "Dashboard::SavedSearches", type: :request, timescaledb: true do
  let(:project) { create(:project) }

  describe "GET /dashboard/projects/:project_id/saved_searches (JSON)" do
    let!(:search) { create(:saved_search, project: project) }

    it "returns saved searches as JSON" do
      get dashboard_project_saved_searches_path(project, format: :json)
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.size).to eq(1)
      expect(body.first["name"]).to eq(search.name)
    end
  end

  describe "POST /dashboard/projects/:project_id/saved_searches" do
    it "creates a saved search (HTML redirect)" do
      expect {
        post dashboard_project_saved_searches_path(project),
             params: { saved_search: { name: "Errors", query: "level:error" } }
      }.to change(SavedSearch, :count).by(1)

      expect(response).to redirect_to(dashboard_project_logs_path(project, q: "level:error"))
    end

    it "creates via JSON" do
      expect {
        post dashboard_project_saved_searches_path(project, format: :json),
             params: { saved_search: { name: "Warnings", query: "level:warn" } }
      }.to change(SavedSearch, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "returns errors for invalid params (JSON)" do
      post dashboard_project_saved_searches_path(project, format: :json),
           params: { saved_search: { name: "", query: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects duplicate names within same project (JSON)" do
      create(:saved_search, project: project, name: "Errors")
      post dashboard_project_saved_searches_path(project, format: :json),
           params: { saved_search: { name: "Errors", query: "level:error" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /dashboard/projects/:project_id/saved_searches/:id" do
    let!(:search) { create(:saved_search, project: project) }

    it "deletes the saved search (HTML redirect)" do
      expect {
        delete dashboard_project_saved_search_path(project, search)
      }.to change(SavedSearch, :count).by(-1)

      expect(response).to redirect_to(dashboard_project_logs_path(project))
    end

    it "deletes via JSON" do
      expect {
        delete dashboard_project_saved_search_path(project, search, format: :json)
      }.to change(SavedSearch, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
