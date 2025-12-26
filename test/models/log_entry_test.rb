require "test_helper"

class LogEntryTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @log_entry = log_entries(:one)
  end

  # Validations
  test "should be valid with valid attributes" do
    assert @log_entry.valid?
  end

  test "should require timestamp" do
    entry = @project.log_entries.build(level: "info", message: "Test")
    entry.timestamp = nil
    assert_not entry.valid?
    assert_includes entry.errors[:timestamp], "can't be blank"
  end

  test "should require level" do
    entry = @project.log_entries.build(timestamp: Time.current, message: "Test")
    entry.level = nil
    assert_not entry.valid?
    assert_includes entry.errors[:level], "can't be blank"
  end

  test "should validate level is in allowed values" do
    entry = @project.log_entries.build(
      timestamp: Time.current,
      level: "invalid",
      message: "Test"
    )
    assert_not entry.valid?
    assert_includes entry.errors[:level], "is not included in the list"
  end

  test "should accept debug level" do
    entry = @project.log_entries.build(
      timestamp: Time.current,
      level: "debug",
      message: "Test"
    )
    assert entry.valid?
  end

  test "should accept info level" do
    entry = @project.log_entries.build(
      timestamp: Time.current,
      level: "info",
      message: "Test"
    )
    assert entry.valid?
  end

  test "should accept warn level" do
    entry = @project.log_entries.build(
      timestamp: Time.current,
      level: "warn",
      message: "Test"
    )
    assert entry.valid?
  end

  test "should accept error level" do
    entry = @project.log_entries.build(
      timestamp: Time.current,
      level: "error",
      message: "Test"
    )
    assert entry.valid?
  end

  test "should accept fatal level" do
    entry = @project.log_entries.build(
      timestamp: Time.current,
      level: "fatal",
      message: "Test"
    )
    assert entry.valid?
  end

  # Associations
  test "should belong to project" do
    assert_equal projects(:one), @log_entry.project
  end

  test "should increment project logs_count on create" do
    initial_count = @project.logs_count
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test counter"
    )
    @project.reload
    assert_equal initial_count + 1, @project.logs_count
  end

  # Default scope
  test "should order by timestamp desc by default" do
    entries = @project.log_entries.to_a
    timestamps = entries.map(&:timestamp)
    assert_equal timestamps.sort.reverse, timestamps
  end

  # Class methods
  test "counts_by_level should return hash of level counts" do
    counts = @project.log_entries.counts_by_level
    assert_kind_of Hash, counts
    assert counts.key?("info") || counts.key?("error") || counts.key?("debug")
  end

  test "recent_counts should return counts since specified time" do
    counts = LogEntry.recent_counts(since: 2.hours.ago)
    assert_kind_of Hash, counts
  end

  test "recent_counts should use default of 1 hour ago" do
    counts = LogEntry.recent_counts
    assert_kind_of Hash, counts
  end

  # JSONB data field
  test "should store and retrieve JSONB data" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test with data",
      data: { user_id: 123, action: "test" }
    )
    entry.reload
    assert_equal 123, entry.data["user_id"]
    assert_equal "test", entry.data["action"]
  end

  test "should handle empty data" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test with no data"
    )
    entry.reload
    assert_equal({}, entry.data)
  end

  test "should handle nested JSONB data" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test with nested data",
      data: {
        user: { id: 123, name: "Test User" },
        metadata: { tags: ["a", "b", "c"] }
      }
    )
    entry.reload
    assert_equal 123, entry.data["user"]["id"]
    assert_equal "Test User", entry.data["user"]["name"]
    assert_equal ["a", "b", "c"], entry.data["metadata"]["tags"]
  end

  # Optional fields
  test "should allow nil message" do
    entry = @project.log_entries.build(
      timestamp: Time.current,
      level: "info",
      message: nil
    )
    assert entry.valid?
  end

  test "should store environment" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      environment: "production"
    )
    assert_equal "production", entry.environment
  end

  test "should store service" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      service: "api"
    )
    assert_equal "api", entry.service
  end

  test "should store host" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      host: "server-1"
    )
    assert_equal "server-1", entry.host
  end

  test "should store commit" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      commit: "abc123"
    )
    assert_equal "abc123", entry.commit
  end

  test "should store branch" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      branch: "main"
    )
    assert_equal "main", entry.branch
  end

  test "should store request_id" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      request_id: "req_123"
    )
    assert_equal "req_123", entry.request_id
  end

  test "should store session_id" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      session_id: "sess_123"
    )
    assert_equal "sess_123", entry.session_id
  end

  # Querying
  test "should query by level" do
    errors = @project.log_entries.where(level: "error")
    assert errors.all? { |e| e.level == "error" }
  end

  test "should query by session_id" do
    session_logs = @project.log_entries.where(session_id: "sess_test_session_1")
    assert session_logs.count > 0
    assert session_logs.all? { |e| e.session_id == "sess_test_session_1" }
  end

  test "should query by timestamp range" do
    recent = @project.log_entries.where("timestamp > ?", 1.hour.ago)
    assert recent.count > 0
  end
end
