require "test_helper"

class Dashboard::LogsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @log_entry = log_entries(:one)
  end

  # Index action
  test "should get index" do
    get dashboard_project_logs_url(@project)

    assert_response :success
  end

  test "should get index with query" do
    get dashboard_project_logs_url(@project, q: "level:info")

    assert_response :success
  end

  test "should get index with offset" do
    get dashboard_project_logs_url(@project, offset: 10)

    assert_response :success
  end

  test "should get index with empty query" do
    get dashboard_project_logs_url(@project, q: "")

    assert_response :success
  end

  test "should get index with stats query" do
    get dashboard_project_logs_url(@project, q: "| stats by:level")

    assert_response :success
  end

  test "should get index with level filter" do
    get dashboard_project_logs_url(@project, q: "level:error")

    assert_response :success
  end

  test "should get index with environment filter" do
    get dashboard_project_logs_url(@project, q: "env:production")

    assert_response :success
  end

  test "should get index with time filter" do
    get dashboard_project_logs_url(@project, q: "since:1h")

    assert_response :success
  end

  test "should get index with complex query" do
    get dashboard_project_logs_url(@project, q: "level:error env:production since:1h")

    assert_response :success
  end

  # Show action
  test "should get show" do
    get dashboard_project_log_url(@project, @log_entry)

    assert_response :success
  end

  # Trace action (request trace)
  test "should get trace" do
    get trace_dashboard_project_logs_url(@project, request_id: "req_test_1")

    assert_response :success
  end

  test "should redirect trace when no logs found" do
    get trace_dashboard_project_logs_url(@project, request_id: "req_nonexistent")

    assert_redirected_to dashboard_project_logs_path(@project)
  end

  test "trace should show all logs for request" do
    # Create multiple logs with same request_id
    request_id = "req_trace_test_#{SecureRandom.hex(4)}"
    3.times do |i|
      @project.log_entries.create!(
        timestamp: Time.current - i.seconds,
        level: %w[info warn error][i],
        message: "Trace log #{i}",
        request_id: request_id,
        service: "web"
      )
    end

    get trace_dashboard_project_logs_url(@project, request_id: request_id)

    assert_response :success
  end

  # Session trace action
  test "should get session_trace" do
    get session_trace_dashboard_project_logs_url(@project, session_id: "sess_test_session_1")

    assert_response :success
  end

  test "should redirect session_trace when no logs found" do
    get session_trace_dashboard_project_logs_url(@project, session_id: "sess_nonexistent")

    assert_redirected_to dashboard_project_logs_path(@project)
  end

  test "session_trace should show all logs for session" do
    session_id = "sess_trace_test_#{SecureRandom.hex(4)}"
    3.times do |i|
      @project.log_entries.create!(
        timestamp: Time.current - i.seconds,
        level: "info",
        message: "Session log #{i}",
        session_id: session_id,
        request_id: "req_#{i}",
        service: "api"
      )
    end

    get session_trace_dashboard_project_logs_url(@project, session_id: session_id)

    assert_response :success
  end

  # Turbo frame handling
  test "should return turbo frame for pagination with offset" do
    get dashboard_project_logs_url(@project, offset: 10),
        headers: { "Turbo-Frame" => "logs_list" }

    assert_response :success
  end
end
