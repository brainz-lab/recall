require "test_helper"

class SavedSearchTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @saved_search = saved_searches(:one)
  end

  # Validations
  test "should be valid with valid attributes" do
    assert @saved_search.valid?
  end

  test "should require name" do
    search = @project.saved_searches.build(query: "level:error")
    search.name = nil
    assert_not search.valid?
    assert_includes search.errors[:name], "can't be blank"
  end

  test "should require query" do
    search = @project.saved_searches.build(name: "Test Search")
    search.query = nil
    assert_not search.valid?
    assert_includes search.errors[:query], "can't be blank"
  end

  test "should enforce maximum name length of 100 characters" do
    search = @project.saved_searches.build(
      name: "a" * 101,
      query: "level:error"
    )
    assert_not search.valid?
    assert_includes search.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "should accept name with exactly 100 characters" do
    search = @project.saved_searches.build(
      name: "a" * 100,
      query: "level:error"
    )
    assert search.valid?
  end

  test "should require unique name within project scope" do
    duplicate = @project.saved_searches.build(
      name: @saved_search.name,
      query: "different query"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "already exists for this project"
  end

  test "should allow same name in different projects" do
    other_project = projects(:two)
    search = other_project.saved_searches.build(
      name: @saved_search.name,
      query: "level:error"
    )
    assert search.valid?
  end

  # Associations
  test "should belong to project" do
    assert_equal @project, @saved_search.project
  end

  # Scopes
  test "ordered scope should order by updated_at desc" do
    # Create some saved searches with different timestamps
    search1 = @project.saved_searches.create!(
      name: "First",
      query: "level:info",
      updated_at: 3.days.ago
    )
    search2 = @project.saved_searches.create!(
      name: "Second",
      query: "level:warn",
      updated_at: 1.day.ago
    )
    search3 = @project.saved_searches.create!(
      name: "Third",
      query: "level:error",
      updated_at: 2.days.ago
    )

    ordered = SavedSearch.ordered.where(id: [search1.id, search2.id, search3.id])
    assert_equal [search2.id, search3.id, search1.id], ordered.pluck(:id)
  end

  # Functionality
  test "should store complex queries" do
    search = @project.saved_searches.create!(
      name: "Complex Query",
      query: 'level:error env:production since:1h "payment failed" data.user_id:123'
    )
    assert_equal 'level:error env:production since:1h "payment failed" data.user_id:123', search.query
  end

  test "should update updated_at on save" do
    original_time = @saved_search.updated_at
    sleep 0.01
    @saved_search.update!(query: "level:warn")
    assert @saved_search.updated_at > original_time
  end

  test "should allow deletion" do
    search = @project.saved_searches.create!(
      name: "To Delete",
      query: "level:info"
    )
    assert_difference "SavedSearch.count", -1 do
      search.destroy
    end
  end
end
