require "test_helper"

class Mcp::Tools::RecallQueryTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @tool = Mcp::Tools::RecallQuery.new(@project)
  end

  test "should have description" do
    assert Mcp::Tools::RecallQuery::DESCRIPTION.present?
    assert_includes Mcp::Tools::RecallQuery::DESCRIPTION, "Query logs"
  end

  test "should have schema with query property" do
    schema = Mcp::Tools::RecallQuery::SCHEMA
    assert_equal "object", schema[:type]
    assert schema[:properties].key?(:query)
    assert schema[:properties].key?(:limit)
    assert_includes schema[:required], "query"
  end

  test "should query logs with simple query" do
    result = @tool.call(query: "level:info")

    assert result.key?(:logs)
    assert result.key?(:count)
  end

  test "should query logs with error level" do
    result = @tool.call(query: "level:error")

    assert result.key?(:logs)
    result[:logs].each do |log|
      assert_equal "error", log["level"]
    end
  end

  test "should use default limit of 100" do
    result = @tool.call(query: "")

    assert result.key?(:logs)
    assert result[:logs].size <= 100
  end

  test "should respect custom limit" do
    # Create enough log entries
    10.times do |i|
      @project.log_entries.create!(
        timestamp: Time.current - i.minutes,
        level: "info",
        message: "Test log #{i}"
      )
    end

    result = @tool.call(query: "level:info", limit: 3)

    assert_equal 3, result[:logs].size
  end

  test "should handle nil limit by using default" do
    result = @tool.call(query: "level:info", limit: nil)

    assert result.key?(:logs)
  end

  test "should return stats when query includes stats command" do
    result = @tool.call(query: "| stats by:level")

    assert result.key?(:stats)
  end

  test "should filter by environment" do
    result = @tool.call(query: "env:production")

    assert result.key?(:logs)
    result[:logs].each do |log|
      assert_equal "production", log["environment"]
    end
  end

  test "should filter by commit" do
    result = @tool.call(query: "commit:abc123")

    assert result.key?(:logs)
    result[:logs].each do |log|
      assert_equal "abc123", log["commit"]
    end
  end
end
