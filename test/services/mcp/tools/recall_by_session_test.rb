require "test_helper"

class Mcp::Tools::RecallBySessionTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @tool = Mcp::Tools::RecallBySession.new(@project)
  end

  test "should have description" do
    assert Mcp::Tools::RecallBySession::DESCRIPTION.present?
    assert_includes Mcp::Tools::RecallBySession::DESCRIPTION, "session"
  end

  test "should have schema with session_id required" do
    schema = Mcp::Tools::RecallBySession::SCHEMA
    assert_equal "object", schema[:type]
    assert schema[:properties].key?(:session_id)
    assert_includes schema[:required], "session_id"
  end

  test "should return logs for session" do
    result = @tool.call(session_id: "sess_test_session_1")

    assert result.key?(:logs)
    assert result.key?(:count)
  end

  test "should only return logs for specified session" do
    result = @tool.call(session_id: "sess_test_session_1")

    result[:logs].each do |log|
      assert_equal "sess_test_session_1", log["session_id"]
    end
  end

  test "should return empty array for unknown session" do
    result = @tool.call(session_id: "sess_nonexistent_session")

    assert result.key?(:logs)
    assert_equal 0, result[:count]
  end

  test "should use limit of 500" do
    # Create many logs for one session
    600.times do |i|
      @project.log_entries.create!(
        timestamp: Time.current - i.seconds,
        level: "info",
        message: "Session log #{i}",
        session_id: "sess_bulk_test"
      )
    end

    result = @tool.call(session_id: "sess_bulk_test")

    assert_equal 500, result[:logs].size
  end
end
