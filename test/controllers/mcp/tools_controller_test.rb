require "test_helper"

class Mcp::ToolsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @headers = { "Authorization" => "Bearer #{@project.api_key}" }
  end

  # Authentication tests
  test "should require authentication" do
    get mcp_tools_url

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Unauthorized", json["error"]
  end

  test "should authenticate with bearer token" do
    get mcp_tools_url, headers: @headers

    assert_response :success
  end

  test "should authenticate with X-API-Key header" do
    get mcp_tools_url, headers: { "X-API-Key" => @project.api_key }

    assert_response :success
  end

  test "should authenticate with query param" do
    get mcp_tools_url(api_key: @project.api_key)

    assert_response :success
  end

  test "should reject invalid api key" do
    get mcp_tools_url, headers: { "Authorization" => "Bearer invalid_key" }

    assert_response :unauthorized
  end

  # Index action - list tools
  test "should list tools" do
    get mcp_tools_url, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("tools")
    assert_kind_of Array, json["tools"]
  end

  test "should list all seven tools" do
    get mcp_tools_url, headers: @headers

    json = JSON.parse(response.body)
    assert_equal 7, json["tools"].length
  end

  test "tools should include name description and schema" do
    get mcp_tools_url, headers: @headers

    json = JSON.parse(response.body)
    json["tools"].each do |tool|
      assert tool.key?("name")
      assert tool.key?("description")
      assert tool.key?("inputSchema")
    end
  end

  # Call action - invoke a tool
  test "should call recall_query tool" do
    post mcp_tool_call_url("recall_query"), params: { query: "level:info" }, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("logs") || json.key?("stats")
  end

  test "should call recall_errors tool" do
    post mcp_tool_call_url("recall_errors"), headers: @headers

    assert_response :success
  end

  test "should call recall_stats tool" do
    post mcp_tool_call_url("recall_stats"), headers: @headers

    assert_response :success
  end

  test "should call recall_new_session tool" do
    post mcp_tool_call_url("recall_new_session"), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("session_id")
  end

  test "should call recall_by_session tool" do
    post mcp_tool_call_url("recall_by_session"),
         params: { session_id: "sess_test" },
         headers: @headers

    assert_response :success
  end

  test "should call recall_request tool" do
    post mcp_tool_call_url("recall_request"),
         params: { request_id: "req_test" },
         headers: @headers

    assert_response :success
  end

  test "should call recall_clear_session tool" do
    post mcp_tool_call_url("recall_clear_session"),
         params: { session_id: "sess_test" },
         headers: @headers

    assert_response :success
  end

  test "should return error for unknown tool" do
    post mcp_tool_call_url("unknown_tool"), headers: @headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json.key?("error")
  end

  # RPC action - JSON-RPC style
  test "should handle tools/list rpc method" do
    post mcp_rpc_url, params: { method: "tools/list" }, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("result")
    assert json["result"].key?("tools")
  end

  test "should handle tools/call rpc method" do
    post mcp_rpc_url, params: {
      method: "tools/call",
      params: { name: "recall_query", arguments: { query: "level:info" } }
    }, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("result")
  end

  test "should return error for unknown rpc method" do
    post mcp_rpc_url, params: { method: "unknown/method" }, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("error")
    assert_equal -32601, json["error"]["code"]
    assert_equal "Method not found", json["error"]["message"]
  end

  test "rpc should handle tools/call without arguments" do
    post mcp_rpc_url, params: {
      method: "tools/call",
      params: { name: "recall_new_session" }
    }, headers: @headers

    assert_response :success
  end
end
