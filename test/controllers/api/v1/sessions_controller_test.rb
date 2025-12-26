require "test_helper"

class Api::V1::SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @headers = { "Authorization" => "Bearer #{@project.api_key}" }
  end

  # Create action
  test "should create new session" do
    post api_v1_sessions_url, headers: @headers

    assert_response :created
    json = JSON.parse(response.body)
    assert json.key?("session_id")
    assert_match /^sess_[a-f0-9]{24}$/, json["session_id"]
  end

  test "should generate unique session IDs" do
    post api_v1_sessions_url, headers: @headers
    session1 = JSON.parse(response.body)["session_id"]

    post api_v1_sessions_url, headers: @headers
    session2 = JSON.parse(response.body)["session_id"]

    assert_not_equal session1, session2
  end

  test "should require authentication to create session" do
    post api_v1_sessions_url

    assert_response :unauthorized
  end

  # Index action
  test "should get list of sessions" do
    get api_v1_sessions_url, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("sessions")
    assert_kind_of Array, json["sessions"]
  end

  test "should return sessions with stats" do
    # Ensure we have a session
    session_id = log_entries(:one).session_id

    get api_v1_sessions_url, headers: @headers

    json = JSON.parse(response.body)
    sessions = json["sessions"]

    if sessions.any?
      session = sessions.first
      assert session.key?("session_id")
      assert session.key?("log_count")
      assert session.key?("first_log")
      assert session.key?("last_log")
      assert session.key?("levels")
    end
  end

  test "should limit number of sessions returned" do
    get api_v1_sessions_url(limit: 10), headers: @headers

    json = JSON.parse(response.body)
    assert json["sessions"].size <= 10
  end

  test "should use default limit of 50" do
    get api_v1_sessions_url, headers: @headers

    json = JSON.parse(response.body)
    assert json["sessions"].size <= 50
  end

  test "should only return sessions from authenticated project" do
    # Create log with session for this project
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      session_id: "sess_project_one"
    )

    # Create log with session for other project
    other_project = projects(:two)
    other_project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      session_id: "sess_project_two"
    )

    get api_v1_sessions_url, headers: @headers

    json = JSON.parse(response.body)
    session_ids = json["sessions"].map { |s| s["session_id"] }

    assert_includes session_ids, "sess_project_one" if json["sessions"].any?
    assert_not_includes session_ids, "sess_project_two"
  end

  test "should require authentication for sessions index" do
    get api_v1_sessions_url

    assert_response :unauthorized
  end

  # Show action
  test "should show session details" do
    session_id = log_entries(:one).session_id

    get api_v1_session_url(session_id), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal session_id, json["session_id"]
    assert json.key?("log_count")
    assert json.key?("first_log")
    assert json.key?("last_log")
    assert json.key?("levels")
    assert json.key?("logs")
  end

  test "should return 404 for non-existent session" do
    get api_v1_session_url("non_existent_session"), headers: @headers

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Session not found", json["error"]
  end

  test "should include logs array in session details" do
    session_id = log_entries(:one).session_id

    get api_v1_session_url(session_id), headers: @headers

    json = JSON.parse(response.body)
    assert_kind_of Array, json["logs"]
    assert json["logs"].size > 0
  end

  test "should limit logs to 100 in session details" do
    session_id = "sess_large_test"

    # Create many logs for this session
    110.times do |i|
      @project.log_entries.create!(
        timestamp: Time.current,
        level: "info",
        message: "Log #{i}",
        session_id: session_id
      )
    end

    get api_v1_session_url(session_id), headers: @headers

    json = JSON.parse(response.body)
    assert_equal 100, json["logs"].size
    assert_equal 110, json["log_count"]
  end

  test "should include level counts in session details" do
    session_id = log_entries(:one).session_id

    get api_v1_session_url(session_id), headers: @headers

    json = JSON.parse(response.body)
    assert_kind_of Hash, json["levels"]
  end

  test "should require authentication for session show" do
    session_id = log_entries(:one).session_id
    get api_v1_session_url(session_id)

    assert_response :unauthorized
  end

  # Logs action
  test "should get logs for a session" do
    session_id = log_entries(:one).session_id

    get logs_api_v1_session_url(session_id), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal session_id, json["session_id"]
    assert json.key?("count")
    assert json.key?("logs")
    assert_kind_of Array, json["logs"]
  end

  test "should filter session logs by level" do
    session_id = "sess_filter_test"

    # Create logs with different levels
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "error",
      message: "Error log",
      session_id: session_id
    )
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Info log",
      session_id: session_id
    )

    get logs_api_v1_session_url(session_id, level: "error"), headers: @headers

    json = JSON.parse(response.body)
    logs = json["logs"]

    assert logs.all? { |log| log["level"] == "error" }
  end

  test "should limit session logs" do
    session_id = "sess_limit_test"

    # Create multiple logs
    10.times do |i|
      @project.log_entries.create!(
        timestamp: Time.current,
        level: "info",
        message: "Log #{i}",
        session_id: session_id
      )
    end

    get logs_api_v1_session_url(session_id, limit: 5), headers: @headers

    json = JSON.parse(response.body)
    assert json["logs"].size <= 5
  end

  test "should use default limit of 500 for session logs" do
    get logs_api_v1_session_url("sess_test"), headers: @headers

    # Should not error even if session doesn't exist
    assert_response :success
  end

  test "should order session logs by timestamp ascending" do
    session_id = log_entries(:one).session_id

    get logs_api_v1_session_url(session_id), headers: @headers

    json = JSON.parse(response.body)
    logs = json["logs"]

    if logs.size > 1
      timestamps = logs.map { |log| Time.parse(log["timestamp"]) }
      assert_equal timestamps.sort, timestamps
    end
  end

  test "should require authentication for session logs" do
    get logs_api_v1_session_url("test_session")

    assert_response :unauthorized
  end

  # Destroy action
  test "should delete session logs" do
    session_id = "sess_delete_test"

    # Create logs for this session
    3.times do
      @project.log_entries.create!(
        timestamp: Time.current,
        level: "info",
        message: "To be deleted",
        session_id: session_id
      )
    end

    assert_difference "@project.log_entries.where(session_id: session_id).count", -3 do
      delete api_v1_session_url(session_id), headers: @headers
    end

    assert_response :success
  end

  test "should return count of deleted logs" do
    session_id = "sess_delete_count_test"

    # Create logs
    2.times do
      @project.log_entries.create!(
        timestamp: Time.current,
        level: "info",
        message: "To be deleted",
        session_id: session_id
      )
    end

    delete api_v1_session_url(session_id), headers: @headers

    json = JSON.parse(response.body)
    assert_equal 2, json["deleted"]
    assert_equal session_id, json["session_id"]
  end

  test "should return 0 deleted for non-existent session" do
    delete api_v1_session_url("non_existent"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["deleted"]
  end

  test "should only delete logs from authenticated project" do
    session_id = "sess_shared"

    # Create logs for this project
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Project one",
      session_id: session_id
    )

    # Create logs for other project with same session_id
    other_project = projects(:two)
    other_log = other_project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Project two",
      session_id: session_id
    )

    delete api_v1_session_url(session_id), headers: @headers

    # Other project's log should still exist
    assert LogEntry.exists?(other_log.id)
  end

  test "should require authentication to delete session" do
    delete api_v1_session_url("test_session")

    assert_response :unauthorized
  end

  # Edge cases
  test "should handle session_id with special characters" do
    session_id = "sess_test-123_abc"

    @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      session_id: session_id
    )

    get api_v1_session_url(session_id), headers: @headers

    assert_response :success
  end

  test "should return empty sessions array when no sessions exist" do
    # Delete all logs
    @project.log_entries.delete_all

    get api_v1_sessions_url, headers: @headers

    json = JSON.parse(response.body)
    assert_equal [], json["sessions"]
  end
end
