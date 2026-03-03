require "rails_helper"

# DevToolsController has `before_action :ensure_development!` which redirects
# in non-development environments. Since tests run in :test env, all actions
# redirect to dashboard_root_path.
RSpec.describe "Dashboard::DevTools", type: :request, timescaledb: true do
  describe "GET /dashboard/dev_tools" do
    it "redirects in test environment (only available in development)" do
      get dashboard_dev_tools_path
      expect(response).to redirect_to(dashboard_root_path)
    end
  end

  describe "POST /dashboard/dev_tools/clean_logs" do
    it "redirects in test environment" do
      post clean_logs_dashboard_dev_tools_path
      expect(response).to redirect_to(dashboard_root_path)
    end
  end

  describe "POST /dashboard/dev_tools/clean_all" do
    it "redirects in test environment" do
      post clean_all_dashboard_dev_tools_path
      expect(response).to redirect_to(dashboard_root_path)
    end
  end
end
