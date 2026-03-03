require "rails_helper"

# BUG: Dashboard layout has ERB syntax error (extra <% end %> on line 114).
# View-rendering actions return 500. Redirect actions still work.
# See QA_BUG_REPORT.md BUG-004.
RSpec.describe "Dashboard::Archives", type: :request, timescaledb: true do
  describe "POST /dashboard/projects/:project_id/archive" do
    context "when archive is enabled" do
      let(:project) { create(:project, :archive_enabled, retention_days: 30) }

      it "runs the archive and redirects" do
        create(:log_entry, :old, project: project)
        post dashboard_project_archive_path(project)
        expect(response).to redirect_to(dashboard_project_archive_path(project))
      end
    end

    context "when archive is not enabled" do
      let(:project) { create(:project, archive_enabled: false) }

      it "redirects with alert" do
        post dashboard_project_archive_path(project)
        expect(response).to redirect_to(dashboard_project_archive_path(project))
        expect(flash[:alert]).to include("not enabled")
      end
    end
  end
end
