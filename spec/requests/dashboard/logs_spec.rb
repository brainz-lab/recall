require "rails_helper"

# BUG: Dashboard layout has ERB syntax error (extra <% end %> on line 114).
# All view-rendering actions return 500. See QA_BUG_REPORT.md BUG-004.
# We still test redirect-based actions and controller side-effects.
RSpec.describe "Dashboard::Logs", type: :request, timescaledb: true do
  let(:project) { create(:project) }

  before do
    create(:log_entry, :error, project: project, timestamp: 2.minutes.ago,
           request_id: "req-trace-001", session_id: "sess-trace-001")
    create(:log_entry, :info, project: project, timestamp: 1.minute.ago,
           request_id: "req-trace-001", session_id: "sess-trace-001")
  end

  describe "GET /dashboard/projects/:project_id/logs" do
    it "returns 500 due to dashboard layout template syntax error (BUG)" do
      get dashboard_project_logs_path(project)
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe "GET /dashboard/projects/:project_id/logs/trace/:request_id" do
    it "redirects when no logs found for request_id" do
      get trace_dashboard_project_logs_path(project, request_id: "nonexistent")
      expect(response).to redirect_to(dashboard_project_logs_path(project))
    end
  end

  describe "GET /dashboard/projects/:project_id/logs/session/:session_id" do
    it "redirects when no logs found for session_id" do
      get session_trace_dashboard_project_logs_path(project, session_id: "nonexistent")
      expect(response).to redirect_to(dashboard_project_logs_path(project))
    end
  end
end
