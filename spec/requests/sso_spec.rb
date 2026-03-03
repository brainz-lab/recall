require "rails_helper"

RSpec.describe "SSO", type: :request do
  let(:platform_internal_url) { ENV.fetch("BRAINZLAB_PLATFORM_URL", "http://platform:3000") }
  let(:platform_external_url) { ENV.fetch("BRAINZLAB_PLATFORM_EXTERNAL_URL", "http://platform.localhost") }

  describe "GET /sso/callback" do
    context "without token" do
      it "redirects to Platform login" do
        get "/sso/callback"
        expect(response).to redirect_to(platform_external_url)
      end
    end

    context "with valid token" do
      let(:sso_response) do
        {
          valid: true,
          user_id: "user-uuid-1",
          user_email: "dev@brainzlab.ai",
          user_name: "Dev User",
          project_id: SecureRandom.uuid,
          project_slug: "my-project",
          organization_id: SecureRandom.uuid
        }
      end

      before do
        stub_request(:post, "#{platform_internal_url}/api/v1/sso/validate")
          .to_return(status: 200, body: sso_response.except(:valid).to_json,
                     headers: { "Content-Type" => "application/json" })

        stub_request(:get, "#{platform_internal_url}/api/v1/user/projects")
          .to_return(status: 200,
                     body: { projects: [{ id: sso_response[:project_id], name: "my-project", slug: "my-project" }] }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "sets session variables and redirects to dashboard" do
        get "/sso/callback", params: { token: "valid-sso-token" }
        expect(response).to have_http_status(:redirect)
      end

      it "creates the project from SSO data if it does not exist" do
        expect {
          get "/sso/callback", params: { token: "valid-sso-token" }
        }.to change(Project, :count).by(1)
      end

      it "does not duplicate projects on repeat SSO" do
        get "/sso/callback", params: { token: "valid-sso-token" }
        expect {
          get "/sso/callback", params: { token: "valid-sso-token" }
        }.not_to change(Project, :count)
      end

      it "redirects to return_to when provided" do
        get "/sso/callback", params: { token: "valid-sso-token", return_to: "/dashboard/projects" }
        expect(response).to redirect_to("/dashboard/projects")
      end
    end

    context "with invalid token" do
      before do
        stub_request(:post, "#{platform_internal_url}/api/v1/sso/validate")
          .to_return(status: 401, body: { error: "Invalid token" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "redirects to Platform login with error" do
        get "/sso/callback", params: { token: "bad-token" }
        expect(response).to redirect_to("#{platform_external_url}/login?error=sso_failed")
      end
    end

    context "when Platform is unreachable" do
      before do
        stub_request(:post, "#{platform_internal_url}/api/v1/sso/validate")
          .to_timeout
      end

      it "redirects to Platform login with error" do
        get "/sso/callback", params: { token: "any-token" }
        expect(response).to redirect_to("#{platform_external_url}/login?error=sso_failed")
      end
    end
  end
end
