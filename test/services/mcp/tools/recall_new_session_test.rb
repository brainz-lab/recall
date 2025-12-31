require "test_helper"

class Mcp::Tools::RecallNewSessionTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @tool = Mcp::Tools::RecallNewSession.new(@project)
  end

  test "should have description" do
    assert Mcp::Tools::RecallNewSession::DESCRIPTION.present?
    assert_includes Mcp::Tools::RecallNewSession::DESCRIPTION, "session"
  end

  test "should have empty schema properties" do
    schema = Mcp::Tools::RecallNewSession::SCHEMA
    assert_equal "object", schema[:type]
    assert schema[:properties].empty?
  end

  test "should return session_id" do
    result = @tool.call({})

    assert result.key?(:session_id)
  end

  test "should generate session_id with sess_ prefix" do
    result = @tool.call({})

    assert result[:session_id].start_with?("sess_")
  end

  test "should generate unique session_id each time" do
    result1 = @tool.call({})
    result2 = @tool.call({})

    assert_not_equal result1[:session_id], result2[:session_id]
  end

  test "should generate 24 character hex after prefix" do
    result = @tool.call({})

    # sess_ is 5 chars, hex is 24 chars (12 bytes = 24 hex chars)
    session_id = result[:session_id]
    hex_part = session_id.sub("sess_", "")

    assert_equal 24, hex_part.length
    assert hex_part.match?(/\A[0-9a-f]+\z/)
  end

  test "should ignore any arguments passed" do
    result = @tool.call(foo: "bar", baz: 123)

    assert result.key?(:session_id)
  end
end
