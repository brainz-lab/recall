require "test_helper"

class Mcp::Tools::RecallRequestTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @tool = Mcp::Tools::RecallRequest.new(@project)
  end

  test "should have description" do
    assert Mcp::Tools::RecallRequest::DESCRIPTION.present?
    assert_includes Mcp::Tools::RecallRequest::DESCRIPTION, "request"
  end

  test "should have schema with request_id required" do
    schema = Mcp::Tools::RecallRequest::SCHEMA
    assert_equal "object", schema[:type]
    assert schema[:properties].key?(:request_id)
    assert_includes schema[:required], "request_id"
  end

  test "should return logs for request" do
    result = @tool.call(request_id: "req_test_1")

    assert result.key?(:logs)
    assert result.key?(:count)
  end

  test "should only return logs for specified request" do
    result = @tool.call(request_id: "req_test_1")

    result[:logs].each do |log|
      assert_equal "req_test_1", log["request_id"]
    end
  end

  test "should return empty array for unknown request" do
    result = @tool.call(request_id: "req_nonexistent_request")

    assert result.key?(:logs)
    assert_equal 0, result[:count]
  end

  test "should use limit of 500" do
    # Create many logs for one request
    600.times do |i|
      @project.log_entries.create!(
        timestamp: Time.current - i.seconds,
        level: "info",
        message: "Request log #{i}",
        request_id: "req_bulk_test"
      )
    end

    result = @tool.call(request_id: "req_bulk_test")

    assert_equal 500, result[:logs].size
  end
end
