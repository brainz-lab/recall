require "test_helper"

class Mcp::ServerTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @server = Mcp::Server.new(@project)
  end

  # list_tools tests
  test "should list all tools" do
    tools = @server.list_tools

    assert_kind_of Array, tools
    assert_equal 7, tools.size
  end

  test "should include tool name in list" do
    tools = @server.list_tools
    tool_names = tools.map { |t| t[:name] }

    assert_includes tool_names, "recall_query"
    assert_includes tool_names, "recall_errors"
    assert_includes tool_names, "recall_stats"
    assert_includes tool_names, "recall_by_session"
    assert_includes tool_names, "recall_request"
    assert_includes tool_names, "recall_new_session"
    assert_includes tool_names, "recall_clear_session"
  end

  test "should include tool description in list" do
    tools = @server.list_tools

    tools.each do |tool|
      assert tool[:description].present?, "Tool #{tool[:name]} should have description"
    end
  end

  test "should include inputSchema in list" do
    tools = @server.list_tools

    tools.each do |tool|
      assert tool[:inputSchema].present?, "Tool #{tool[:name]} should have inputSchema"
      assert_equal "object", tool[:inputSchema][:type]
    end
  end

  # call_tool tests
  test "should call recall_query tool" do
    result = @server.call_tool("recall_query", { query: "level:info" })

    assert result.key?(:logs) || result.key?(:stats)
  end

  test "should call recall_errors tool" do
    result = @server.call_tool("recall_errors", {})

    assert result.key?(:logs) || result.key?(:stats)
  end

  test "should call recall_stats tool" do
    result = @server.call_tool("recall_stats", {})

    assert result.key?(:stats) || result.key?(:logs)
  end

  test "should call recall_new_session tool" do
    result = @server.call_tool("recall_new_session", {})

    assert result.key?(:session_id)
    assert result[:session_id].start_with?("sess_")
  end

  test "should call recall_by_session tool" do
    result = @server.call_tool("recall_by_session", { session_id: "sess_test_session_1" })

    assert result.key?(:logs)
    assert result.key?(:count)
  end

  test "should call recall_request tool" do
    result = @server.call_tool("recall_request", { request_id: "req_test_1" })

    assert result.key?(:logs)
    assert result.key?(:count)
  end

  test "should call recall_clear_session tool" do
    # Create a log entry with a test session
    log = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test log for clearing",
      session_id: "sess_to_clear_123"
    )

    result = @server.call_tool("recall_clear_session", { session_id: "sess_to_clear_123" })

    assert result.key?(:deleted)
    assert result.key?(:session_id)
    assert_equal "sess_to_clear_123", result[:session_id]
    assert_equal 1, result[:deleted]
  end

  test "should raise error for unknown tool" do
    assert_raises RuntimeError do
      @server.call_tool("unknown_tool", {})
    end
  end

  test "should handle string arguments by symbolizing keys" do
    result = @server.call_tool("recall_query", { "query" => "level:info", "limit" => 10 })

    assert result.key?(:logs) || result.key?(:stats)
  end
end
