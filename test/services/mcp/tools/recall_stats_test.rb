require "test_helper"

class Mcp::Tools::RecallStatsTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @tool = Mcp::Tools::RecallStats.new(@project)
  end

  test "should have description" do
    assert Mcp::Tools::RecallStats::DESCRIPTION.present?
    assert_includes Mcp::Tools::RecallStats::DESCRIPTION, "statistics"
  end

  test "should have schema with since and by properties" do
    schema = Mcp::Tools::RecallStats::SCHEMA
    assert_equal "object", schema[:type]
    assert schema[:properties].key?(:since)
    assert schema[:properties].key?(:by)
  end

  test "should return stats" do
    result = @tool.call({})

    assert result.key?(:stats)
  end

  test "should use default since of 24h" do
    result = @tool.call({})

    assert result.key?(:stats)
  end

  test "should group by level" do
    result = @tool.call(by: "level")

    assert result.key?(:stats)
  end

  test "should group by commit" do
    result = @tool.call(by: "commit")

    assert result.key?(:stats)
  end

  test "should group by hour" do
    result = @tool.call(by: "hour")

    assert result.key?(:stats)
  end

  test "should group by day" do
    result = @tool.call(by: "day")

    assert result.key?(:stats)
  end

  test "should handle custom since" do
    result = @tool.call(since: "7d")

    assert result.key?(:stats)
  end

  test "should handle nil arguments" do
    result = @tool.call(since: nil, by: nil)

    assert result.key?(:stats)
  end
end
