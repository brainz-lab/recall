require "test_helper"

class Mcp::Tools::BaseTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
  end

  test "should initialize with project" do
    tool = Mcp::Tools::Base.new(@project)
    assert_not_nil tool
  end

  test "call should raise NotImplementedError" do
    tool = Mcp::Tools::Base.new(@project)
    assert_raises NotImplementedError do
      tool.call({})
    end
  end

  test "query_logs should return logs for simple query" do
    tool = TestTool.new(@project)
    result = tool.test_query_logs("level:info")

    assert result.key?(:logs)
    assert result.key?(:count)
  end

  test "query_logs should return stats when query has stats command" do
    tool = TestTool.new(@project)
    result = tool.test_query_logs("since:24h | stats by:level")

    assert result.key?(:stats)
  end

  test "query_logs should respect limit parameter" do
    # Create extra log entries
    5.times do |i|
      @project.log_entries.create!(
        timestamp: Time.current,
        level: "info",
        message: "Test log #{i}"
      )
    end

    tool = TestTool.new(@project)
    result = tool.test_query_logs("level:info", limit: 2)

    assert_equal 2, result[:logs].size
  end

  private

  # Test subclass to access protected methods
  class TestTool < Mcp::Tools::Base
    def test_query_logs(q, limit: 100)
      query_logs(q, limit: limit)
    end
  end
end
