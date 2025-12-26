require "test_helper"

class Api::V1::IngestControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @headers = { "Authorization" => "Bearer #{@project.ingest_key}" }
  end

  # Single log ingestion
  test "should create log entry with valid params" do
    assert_difference "LogEntry.count", 1 do
      post api_v1_log_url,
           params: {
             level: "info",
             message: "Test log message"
           },
           headers: @headers,
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_not_nil json["id"]
  end

  test "should create log with all optional fields" do
    post api_v1_log_url,
         params: {
           level: "error",
           message: "Error message",
           environment: "production",
           service: "api",
           host: "server-1",
           commit: "abc123",
           branch: "main",
           request_id: "req_123",
           session_id: "sess_123",
           data: { user_id: 456, action: "test" }
         },
         headers: @headers,
         as: :json

    assert_response :created

    entry = LogEntry.find(JSON.parse(response.body)["id"])
    assert_equal "error", entry.level
    assert_equal "Error message", entry.message
    assert_equal "production", entry.environment
    assert_equal "api", entry.service
    assert_equal "server-1", entry.host
    assert_equal "abc123", entry.commit
    assert_equal "main", entry.branch
    assert_equal "req_123", entry.request_id
    assert_equal "sess_123", entry.session_id
    assert_equal 456, entry.data["user_id"]
    assert_equal "test", entry.data["action"]
  end

  test "should use default timestamp if not provided" do
    freeze_time do
      post api_v1_log_url,
           params: { level: "info", message: "Test" },
           headers: @headers,
           as: :json

      assert_response :created
      entry = LogEntry.find(JSON.parse(response.body)["id"])
      assert_in_delta Time.current.to_i, entry.timestamp.to_i, 1
    end
  end

  test "should use default level info if not provided" do
    post api_v1_log_url,
         params: { message: "Test without level" },
         headers: @headers,
         as: :json

    assert_response :created
    entry = LogEntry.find(JSON.parse(response.body)["id"])
    assert_equal "info", entry.level
  end

  test "should accept custom timestamp" do
    custom_time = 1.hour.ago
    post api_v1_log_url,
         params: {
           timestamp: custom_time.iso8601,
           level: "info",
           message: "Test"
         },
         headers: @headers,
         as: :json

    assert_response :created
    entry = LogEntry.find(JSON.parse(response.body)["id"])
    assert_in_delta custom_time.to_i, entry.timestamp.to_i, 1
  end

  test "should associate log with authenticated project" do
    post api_v1_log_url,
         params: { level: "info", message: "Test" },
         headers: @headers,
         as: :json

    assert_response :created
    entry = LogEntry.find(JSON.parse(response.body)["id"])
    assert_equal @project.id, entry.project_id
  end

  # Batch ingestion
  test "should ingest multiple logs in batch" do
    logs = [
      { level: "info", message: "Log 1" },
      { level: "error", message: "Log 2" },
      { level: "warn", message: "Log 3" }
    ]

    assert_difference "LogEntry.count", 3 do
      post api_v1_batch_url,
           params: { logs: logs },
           headers: @headers,
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 3, json["ingested"]
  end

  test "should handle empty batch" do
    assert_no_difference "LogEntry.count" do
      post api_v1_batch_url,
           params: { logs: [] },
           headers: @headers,
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 0, json["ingested"]
  end

  test "should ingest batch with _json root" do
    logs = [
      { level: "info", message: "Log 1" },
      { level: "info", message: "Log 2" }
    ]

    assert_difference "LogEntry.count", 2 do
      post api_v1_batch_url,
           params: logs,
           headers: @headers,
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 2, json["ingested"]
  end

  test "should ingest batch with all fields" do
    logs = [
      {
        level: "error",
        message: "Batch error",
        environment: "production",
        service: "worker",
        data: { error_code: 500 }
      },
      {
        level: "info",
        message: "Batch info",
        commit: "def456"
      }
    ]

    post api_v1_batch_url,
         params: { logs: logs },
         headers: @headers,
         as: :json

    assert_response :created

    # Verify logs were created with correct data
    recent_logs = @project.log_entries.order(created_at: :desc).limit(2)
    messages = recent_logs.pluck(:message)
    assert_includes messages, "Batch error"
    assert_includes messages, "Batch info"
  end

  test "batch should handle logs with nested data" do
    logs = [
      {
        level: "info",
        message: "Test",
        data: {
          user: { id: 123, name: "Test" },
          metadata: { tags: ["a", "b"] }
        }
      }
    ]

    assert_difference "LogEntry.count", 1 do
      post api_v1_batch_url,
           params: { logs: logs },
           headers: @headers,
           as: :json
    end

    assert_response :created
  end

  # Authentication
  test "should require authentication for single log" do
    post api_v1_log_url,
         params: { level: "info", message: "Test" },
         as: :json

    assert_response :unauthorized
  end

  test "should require authentication for batch" do
    post api_v1_batch_url,
         params: { logs: [{ level: "info", message: "Test" }] },
         as: :json

    assert_response :unauthorized
  end

  test "should accept ingest_key for authentication" do
    headers = { "Authorization" => "Bearer #{@project.ingest_key}" }

    post api_v1_log_url,
         params: { level: "info", message: "Test" },
         headers: headers,
         as: :json

    assert_response :created
  end

  test "should accept api_key for authentication" do
    headers = { "Authorization" => "Bearer #{@project.api_key}" }

    post api_v1_log_url,
         params: { level: "info", message: "Test" },
         headers: headers,
         as: :json

    assert_response :created
  end

  # Error handling
  test "should handle invalid level gracefully" do
    # This depends on validation - the model validates level
    # If validation fails, controller should handle it
    post api_v1_log_url,
         params: { level: "invalid", message: "Test" },
         headers: @headers,
         as: :json

    # Should either reject or convert to valid level
    # Based on the code, it will fail validation
    assert_response :unprocessable_entity
  end

  # Data field handling
  test "should store empty hash for missing data field" do
    post api_v1_log_url,
         params: { level: "info", message: "Test" },
         headers: @headers,
         as: :json

    assert_response :created
    entry = LogEntry.find(JSON.parse(response.body)["id"])
    assert_equal({}, entry.data)
  end

  test "should properly serialize complex data structures" do
    complex_data = {
      arrays: [1, 2, 3],
      nested: { deep: { value: "test" } },
      boolean: true,
      null_value: nil
    }

    post api_v1_log_url,
         params: {
           level: "info",
           message: "Complex data test",
           data: complex_data
         },
         headers: @headers,
         as: :json

    assert_response :created
    entry = LogEntry.find(JSON.parse(response.body)["id"])
    assert_equal [1, 2, 3], entry.data["arrays"]
    assert_equal "test", entry.data["nested"]["deep"]["value"]
    assert_equal true, entry.data["boolean"]
  end

  # Bulk insert performance
  test "should handle large batches efficiently" do
    logs = 100.times.map do |i|
      {
        level: "info",
        message: "Bulk test #{i}",
        data: { index: i }
      }
    end

    assert_difference "LogEntry.count", 100 do
      post api_v1_batch_url,
           params: { logs: logs },
           headers: @headers,
           as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 100, json["ingested"]
  end
end
