require "rails_helper"

# BUG: The dashboard layout template (app/views/layouts/dashboard.html.erb:114)
# has an extra `<% end %>` tag with no matching opening block. This causes
# ActionView::SyntaxErrorInTemplate for ALL actions that render views.
# Only redirect-based actions can be tested successfully.
# See QA_BUG_REPORT.md BUG-004.
RSpec.describe "Dashboard::Projects", type: :request, timescaledb: true do
  let!(:project) { create(:project) }

  describe "GET /dashboard/projects" do
    it "returns 500 due to dashboard layout template syntax error (BUG)" do
      get dashboard_projects_path
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe "GET /dashboard/projects/:id" do
    it "redirects to the project's logs page" do
      get dashboard_project_path(project)
      expect(response).to redirect_to(dashboard_project_logs_path(project))
    end
  end

  describe "POST /dashboard/projects" do
    it "creates a new project and redirects to setup" do
      expect {
        post dashboard_projects_path, params: { project: { name: "New Project" } }
      }.to change(Project, :count).by(1)

      new_project = Project.order(created_at: :desc).first
      expect(response).to redirect_to(setup_dashboard_project_path(new_project))
    end

    it "does not create project with blank name" do
      expect {
        post dashboard_projects_path, params: { project: { name: "" } }
      }.not_to change(Project, :count)
    end

    it "does not create project with duplicate name" do
      expect {
        post dashboard_projects_path, params: { project: { name: project.name } }
      }.not_to change(Project, :count)
    end
  end

  describe "PATCH /dashboard/projects/:id" do
    it "updates the project and redirects" do
      patch dashboard_project_path(project), params: { project: { name: "Updated Name" } }
      expect(response).to redirect_to(dashboard_project_logs_path(project))
      expect(project.reload.name).to eq("Updated Name")
    end

    it "does not update with blank name" do
      patch dashboard_project_path(project), params: { project: { name: "" } }
      expect(project.reload.name).not_to eq("")
    end
  end

  describe "DELETE /dashboard/projects/:id" do
    it "deletes the project and redirects" do
      expect {
        delete dashboard_project_path(project)
      }.to change(Project, :count).by(-1)

      expect(response).to redirect_to(dashboard_projects_path)
    end
  end

  describe "GET /dashboard/projects/:id/setup" do
    it "preserves existing api_key on setup" do
      original_key = project.api_key
      get setup_dashboard_project_path(project)
      expect(project.reload.api_key).to eq(original_key)
    end
  end

  describe "POST /dashboard/projects/:id/regenerate_mcp_token" do
    it "regenerates the API key and redirects" do
      old_key = project.api_key
      post regenerate_mcp_token_dashboard_project_path(project)
      expect(project.reload.api_key).not_to eq(old_key)
      expect(project.api_key).to start_with("rcl_api_")
      expect(response).to redirect_to(mcp_setup_dashboard_project_path(project))
    end
  end
end
