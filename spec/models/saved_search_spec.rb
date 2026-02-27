require "rails_helper"

RSpec.describe SavedSearch, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "validations" do
    subject { build(:saved_search) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:query) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }

    it "validates uniqueness of name scoped to project" do
      project = create(:project)
      create(:saved_search, project: project, name: "My Search")
      duplicate = build(:saved_search, project: project, name: "My Search")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("already exists for this project")
    end

    it "allows the same name in different projects" do
      project1 = create(:project)
      project2 = create(:project)
      create(:saved_search, project: project1, name: "My Search")
      duplicate = build(:saved_search, project: project2, name: "My Search")
      expect(duplicate).to be_valid
    end
  end

  describe "scopes" do
    describe ".ordered" do
      it "returns searches ordered by updated_at descending" do
        project = create(:project)
        old_search    = create(:saved_search, project: project)
        recent_search = create(:saved_search, project: project)

        old_search.update!(query: "level:debug")   # bumps updated_at for old_search
        Timecop.travel(1.second) do
          recent_search.update!(query: "level:info") # even more recent
        end

        ordered = project.saved_searches.ordered.to_a
        expect(ordered.first).to eq(recent_search)
        expect(ordered.last).to eq(old_search)
      end
    end
  end
end
