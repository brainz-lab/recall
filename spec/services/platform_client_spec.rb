require "rails_helper"

RSpec.describe PlatformClient, type: :service do
  let(:platform_url) { "https://platform.brainzlab.ai" }
  let(:valid_key)    { "sk_live_abc123" }
  let(:valid_response_body) do
    {
      valid: true,
      project_id: "plat-proj-uuid",
      project_slug: "my-project",
      organization_id: "org-uuid",
      organization_slug: "my-org",
      environment: "production",
      plan: "pro",
      scopes: [ "read", "write" ]
    }.to_json
  end

  before do
    Rails.cache.clear
  end

  describe ".validate_key" do
    context "with a blank key" do
      it "returns an invalid result without making HTTP requests" do
        result = PlatformClient.validate_key("")
        expect(result.valid?).to be false
        expect(result.error).to eq("Key required")
      end

      it "returns an invalid result for nil key" do
        result = PlatformClient.validate_key(nil)
        expect(result.valid?).to be false
      end
    end

    context "with a valid key" do
      before do
        stub_request(:post, "#{platform_url}/api/v1/keys/validate")
          .with(body: { key: valid_key }.to_json)
          .to_return(status: 200, body: valid_response_body, headers: { "Content-Type" => "application/json" })
      end

      it "returns a valid ValidationResult" do
        result = PlatformClient.validate_key(valid_key)
        expect(result.valid?).to be true
        expect(result.project_id).to eq("plat-proj-uuid")
        expect(result.project_slug).to eq("my-project")
        expect(result.environment).to eq("production")
        expect(result.plan).to eq("pro")
        expect(result.scopes).to eq([ "read", "write" ])
      end

      it "caches the result on repeat calls" do
        PlatformClient.validate_key(valid_key)
        PlatformClient.validate_key(valid_key)

        # Only 1 HTTP request despite 2 calls
        expect(WebMock).to have_requested(:post, "#{platform_url}/api/v1/keys/validate").once
      end
    end

    context "with an invalid key" do
      before do
        stub_request(:post, "#{platform_url}/api/v1/keys/validate")
          .to_return(status: 401,
                     body: { error: "Invalid key" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns an invalid result with the error message" do
        result = PlatformClient.validate_key("sk_live_bad")
        expect(result.valid?).to be false
        expect(result.error).to eq("Invalid key")
      end
    end

    context "on timeout" do
      before do
        stub_request(:post, "#{platform_url}/api/v1/keys/validate")
          .to_timeout
      end

      it "returns an invalid result with timeout error" do
        result = PlatformClient.validate_key(valid_key)
        expect(result.valid?).to be false
        expect(result.error).to include("timeout")
      end
    end
  end

  describe ".find_or_create_project" do
    let(:valid_result) do
      PlatformClient::ValidationResult.new(
        valid: true,
        project_id: "plat-proj-uuid",
        project_slug: "my-project",
        organization_id: "org-uuid",
        organization_slug: "my-org",
        environment: "production",
        plan: "pro",
        scopes: []
      )
    end

    context "when result is invalid" do
      it "returns nil" do
        invalid_result = PlatformClient::ValidationResult.new(valid: false, error: "bad")
        expect(PlatformClient.find_or_create_project(invalid_result, valid_key)).to be_nil
      end
    end

    context "when project does not exist yet" do
      it "creates a new project from Platform data" do
        expect {
          PlatformClient.find_or_create_project(valid_result, valid_key)
        }.to change(Project, :count).by(1)

        project = Project.find_by(platform_project_id: "plat-proj-uuid")
        expect(project).to be_present
        expect(project.name).to eq("my-project")
        expect(project.api_key).to eq(valid_key)
        expect(project.ingest_key).to eq(valid_key)
        expect(project.environment).to eq("production")
      end
    end

    context "when project already exists" do
      let!(:existing) do
        create(:project,
               platform_project_id: "plat-proj-uuid",
               api_key: valid_key,
               ingest_key: valid_key)
      end

      it "returns the existing project without creating a new one" do
        expect {
          PlatformClient.find_or_create_project(valid_result, valid_key)
        }.not_to change(Project, :count)
      end

      it "updates the api_key if it changed in Platform" do
        new_key = "sk_live_new_key_xyz"
        project = PlatformClient.find_or_create_project(valid_result, new_key)
        expect(project.api_key).to eq(new_key)
        expect(project.ingest_key).to eq(new_key)
      end
    end
  end

  describe "ValidationResult" do
    it "exposes valid? as boolean" do
      result = PlatformClient::ValidationResult.new(valid: true, project_id: "x")
      expect(result.valid?).to be true
    end

    it "defaults scopes to empty array when not provided" do
      result = PlatformClient::ValidationResult.new(valid: true)
      expect(result.scopes).to eq([])
    end
  end
end
