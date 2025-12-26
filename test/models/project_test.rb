require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
  end

  # Validations
  test "should be valid with valid attributes" do
    assert @project.valid?
  end

  test "should require name" do
    @project.name = nil
    assert_not @project.valid?
    assert_includes @project.errors[:name], "can't be blank"
  end

  test "should require slug" do
    @project.slug = nil
    assert_not @project.valid?
    assert_includes @project.errors[:slug], "can't be blank"
  end

  test "should require unique slug" do
    duplicate = Project.new(name: "New Project", slug: @project.slug)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "should require ingest_key" do
    @project.ingest_key = nil
    assert_not @project.valid?
    assert_includes @project.errors[:ingest_key], "can't be blank"
  end

  test "should require unique ingest_key" do
    duplicate = Project.new(
      name: "New Project",
      slug: "new-project",
      ingest_key: @project.ingest_key,
      api_key: "unique_key"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:ingest_key], "has already been taken"
  end

  test "should require api_key" do
    @project.api_key = nil
    assert_not @project.valid?
    assert_includes @project.errors[:api_key], "can't be blank"
  end

  test "should require unique api_key" do
    duplicate = Project.new(
      name: "New Project",
      slug: "new-project",
      ingest_key: "unique_ingest",
      api_key: @project.api_key
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:api_key], "has already been taken"
  end

  # Associations
  test "should have many log_entries" do
    assert_respond_to @project, :log_entries
  end

  test "should have many saved_searches" do
    assert_respond_to @project, :saved_searches
  end

  test "should delete all log_entries when destroyed" do
    project = Project.create!(name: "Test Delete", slug: "test-delete")
    project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test"
    )

    assert_difference "LogEntry.count", -1 do
      project.destroy
    end
  end

  test "should destroy saved_searches when destroyed" do
    project = Project.create!(name: "Test Delete", slug: "test-delete-searches")
    project.saved_searches.create!(name: "Test Search", query: "level:error")

    assert_difference "SavedSearch.count", -1 do
      project.destroy
    end
  end

  # Callbacks
  test "should generate slug from name on create" do
    project = Project.new(name: "My New Project")
    project.save!
    assert_equal "my-new-project", project.slug
  end

  test "should not override manually set slug" do
    project = Project.new(name: "My New Project", slug: "custom-slug")
    project.save!
    assert_equal "custom-slug", project.slug
  end

  test "should generate ingest_key on create" do
    project = Project.new(name: "Key Test")
    project.save!
    assert_match /^rcl_ingest_[a-f0-9]{32}$/, project.ingest_key
  end

  test "should generate api_key on create" do
    project = Project.new(name: "Key Test 2")
    project.save!
    assert_match /^rcl_api_[a-f0-9]{32}$/, project.api_key
  end

  test "should not override manually set ingest_key" do
    custom_key = "rcl_ingest_custom1234567890abcdef1234"
    project = Project.new(name: "Custom Key", ingest_key: custom_key)
    project.save!
    assert_equal custom_key, project.ingest_key
  end

  test "should not override manually set api_key" do
    custom_key = "rcl_api_custom1234567890abcdef123456"
    project = Project.new(name: "Custom Key 2", api_key: custom_key)
    project.save!
    assert_equal custom_key, project.api_key
  end

  # Default values
  test "should have default logs_count of 0" do
    project = Project.create!(name: "Default Test")
    assert_equal 0, project.logs_count
  end

  test "should have default bytes_total of 0" do
    project = Project.create!(name: "Default Test 2")
    assert_equal 0, project.bytes_total
  end

  test "should have default retention_days of 30" do
    project = Project.create!(name: "Default Test 3")
    assert_equal 30, project.retention_days
  end
end
