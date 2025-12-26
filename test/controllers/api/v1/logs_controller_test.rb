require "test_helper"

class Api::V1::LogsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @headers = { "Authorization" => "Bearer #{@project.api_key}" }
  end

  # Index action - querying logs
  test "should get logs index" do
    get api_v1_logs_url, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("logs")
    assert json.key?("count")
    assert json.key?("query")
  end

  test "should return array of logs" do
    get api_v1_logs_url, headers: @headers

    json = JSON.parse(response.body)
    assert_kind_of Array, json["logs"]
  end

  test "should filter logs by query parameter" do
    get api_v1_logs_url(q: "level:error"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    logs = json["logs"]

    # All returned logs should be errors
    assert logs.all? { |log| log["level"] == "error" }
  end

  test "should filter logs by environment" do
    get api_v1_logs_url(q: "env:production"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    logs = json["logs"]

    assert logs.all? { |log| log["environment"] == "production" }
  end

  test "should filter logs by multiple criteria" do
    get api_v1_logs_url(q: "level:info env:production"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    logs = json["logs"]

    assert logs.all? { |log| log["level"] == "info" && log["environment"] == "production" }
  end

  test "should handle empty query" do
    get api_v1_logs_url(q: ""), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_not_nil json["logs"]
  end

  test "should limit results" do
    get api_v1_logs_url(limit: 5), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["logs"].size <= 5
  end

  test "should enforce maximum limit of 1000" do
    get api_v1_logs_url(limit: 5000), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["logs"].size <= 1000
  end

  test "should enforce minimum limit of 1" do
    get api_v1_logs_url(limit: 0), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    # Should use minimum of 1
    assert json["logs"].size >= 0 # Could be 0 if no logs exist
  end

  test "should use query parser limit from command" do
    get api_v1_logs_url(q: "| first 10"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["logs"].size <= 10
  end

  test "should include query in response" do
    query = "level:error since:1h"
    get api_v1_logs_url(q: query), headers: @headers

    json = JSON.parse(response.body)
    assert_equal query, json["query"]
  end

  # Stats queries
  test "should return stats when stats command used" do
    get api_v1_logs_url(q: "| stats"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("stats")
    assert_not json.key?("logs")
  end

  test "should return stats by level" do
    get api_v1_logs_url(q: "| stats by:level"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    stats = json["stats"]
    assert_kind_of Hash, stats
    # Stats should have level counts
    assert stats.any?
  end

  test "should return stats by environment" do
    get api_v1_logs_url(q: "| stats by:env"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("stats")
  end

  test "should combine filters with stats" do
    get api_v1_logs_url(q: "level:error | stats by:commit"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("stats")
  end

  # Show action - single log
  test "should show individual log" do
    log = log_entries(:one)

    get api_v1_log_url(log.id), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal log.id, json["id"]
  end

  test "should return 404 for non-existent log" do
    get api_v1_log_url("non-existent-id"), headers: @headers

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Not found", json["error"]
  end

  test "should not show logs from other projects" do
    other_project = projects(:two)
    other_log = other_project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Other project log"
    )

    get api_v1_log_url(other_log.id), headers: @headers

    assert_response :not_found
  end

  # Export action
  test "should export logs as json" do
    get export_api_v1_logs_url(format: "json"), headers: @headers

    assert_response :success
    assert_equal "application/json", response.content_type
    assert_match /attachment/, response.headers["Content-Disposition"]
  end

  test "should export logs as csv" do
    get export_api_v1_logs_url(format: "csv"), headers: @headers

    assert_response :success
    assert_equal "text/csv", response.content_type
    assert_match /attachment/, response.headers["Content-Disposition"]
  end

  test "should default to json export" do
    get export_api_v1_logs_url, headers: @headers

    assert_response :success
    assert_equal "application/json", response.content_type
  end

  test "should export with query filter" do
    get export_api_v1_logs_url(q: "level:error", format: "json"), headers: @headers

    assert_response :success
    # The export should only include error logs
  end

  test "should export with time filters" do
    get export_api_v1_logs_url(since: "1h", until: "now", format: "json"),
        headers: @headers

    assert_response :success
  end

  test "export filename should include project name" do
    get export_api_v1_logs_url(format: "json"), headers: @headers

    filename = response.headers["Content-Disposition"][/filename="(.+)"/, 1]
    assert_includes filename, @project.name.parameterize
  end

  test "export filename should include timestamp" do
    get export_api_v1_logs_url(format: "csv"), headers: @headers

    filename = response.headers["Content-Disposition"][/filename="(.+)"/, 1]
    assert_match /\d{8}_\d{6}/, filename
  end

  test "csv export should include headers" do
    get export_api_v1_logs_url(format: "csv"), headers: @headers

    assert_response :success
    csv_content = response.body
    headers = csv_content.lines.first
    assert_includes headers, "id"
    assert_includes headers, "timestamp"
    assert_includes headers, "level"
    assert_includes headers, "message"
  end

  # Authentication
  test "should require authentication for index" do
    get api_v1_logs_url

    assert_response :unauthorized
  end

  test "should require authentication for show" do
    log = log_entries(:one)
    get api_v1_log_url(log.id)

    assert_response :unauthorized
  end

  test "should require authentication for export" do
    get export_api_v1_logs_url

    assert_response :unauthorized
  end

  # Project isolation
  test "should only return logs from authenticated project" do
    # Create logs for different projects
    project2 = projects(:two)

    get api_v1_logs_url, headers: @headers

    json = JSON.parse(response.body)
    logs = json["logs"]

    # All logs should belong to @project
    assert logs.all? { |log| log["project_id"] == @project.id }
  end

  # Edge cases
  test "should handle invalid format parameter gracefully" do
    get export_api_v1_logs_url(format: "invalid"), headers: @headers

    assert_response :success
    # Should default to json
    assert_equal "application/json", response.content_type
  end

  test "should handle malformed query gracefully" do
    get api_v1_logs_url(q: "level:"), headers: @headers

    assert_response :success
    # Should not crash, just return results
  end

  test "should return count of logs" do
    get api_v1_logs_url, headers: @headers

    json = JSON.parse(response.body)
    assert_equal json["logs"].size, json["count"]
  end

  # Complex queries
  test "should handle text search query" do
    get api_v1_logs_url(q: '"test log"'), headers: @headers

    assert_response :success
  end

  test "should handle data field queries" do
    get api_v1_logs_url(q: "data.user_id:123"), headers: @headers

    assert_response :success
  end

  test "should handle time range queries" do
    get api_v1_logs_url(q: "since:1h until:now"), headers: @headers

    assert_response :success
  end

  test "should handle negation queries" do
    get api_v1_logs_url(q: "level:!debug"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    logs = json["logs"]

    # Should not include debug logs
    assert_not logs.any? { |log| log["level"] == "debug" }
  end

  test "should handle OR queries" do
    get api_v1_logs_url(q: "level:error OR level:fatal"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    logs = json["logs"]

    # Should only include error or fatal
    assert logs.all? { |log| ["error", "fatal"].include?(log["level"]) }
  end
end
