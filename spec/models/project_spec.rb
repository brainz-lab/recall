require "rails_helper"

RSpec.describe Project, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:log_entries).dependent(:delete_all) }
    it { is_expected.to have_many(:saved_searches).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:project) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:ingest_key) }
    it { is_expected.to validate_presence_of(:api_key) }
  end

  describe "scopes" do
    let!(:active_project)   { create(:project) }
    let!(:archived_project) { create(:project, :archived) }

    describe ".active" do
      it "returns only projects with no archived_at" do
        expect(Project.active).to include(active_project)
        expect(Project.active).not_to include(archived_project)
      end
    end

    describe ".archived" do
      it "returns only archived projects" do
        expect(Project.archived).to include(archived_project)
        expect(Project.archived).not_to include(active_project)
      end
    end
  end

  describe "callbacks" do
    describe "#generate_slug" do
      it "generates slug from name on create" do
        project = create(:project, name: "My Cool Project")
        expect(project.slug).to eq("my-cool-project")
      end

      it "does not overwrite an existing slug" do
        project = build(:project, name: "My Project")
        project.slug = "custom-slug"
        project.save!
        expect(project.slug).to eq("custom-slug")
      end
    end

    describe "#generate_keys" do
      it "generates ingest_key with rcl_ingest_ prefix on create" do
        project = create(:project)
        expect(project.ingest_key).to start_with("rcl_ingest_")
      end

      it "generates api_key with rcl_api_ prefix on create" do
        project = create(:project)
        expect(project.api_key).to start_with("rcl_api_")
      end

      it "does not overwrite existing keys that look like Platform keys" do
        project = build(:project)
        project.api_key = "sk_live_abc123"
        project.ingest_key = "sk_live_abc123"
        project.save!
        expect(project.api_key).to eq("sk_live_abc123")
        expect(project.ingest_key).to eq("sk_live_abc123")
      end

      it "generates unique keys for each project" do
        project1 = create(:project)
        project2 = create(:project)
        expect(project1.api_key).not_to eq(project2.api_key)
        expect(project1.ingest_key).not_to eq(project2.ingest_key)
      end
    end
  end

  describe "#platform_linked?" do
    it "returns true when platform_project_id is present" do
      project = build(:project, :with_platform)
      expect(project.platform_linked?).to be true
    end

    it "returns false when platform_project_id is blank" do
      project = build(:project)
      expect(project.platform_linked?).to be false
    end
  end
end
