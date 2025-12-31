require "test_helper"

class Mcp::Tools::RecallErrorsTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @tool = Mcp::Tools::RecallErrors.new(@project)
  end

  test "should have description" do
    assert Mcp::Tools::RecallErrors::DESCRIPTION.present?
    assert_includes Mcp::Tools::RecallErrors::DESCRIPTION, "error"
  end

  test "should have schema with since and commit properties" do
    schema = Mcp::Tools::RecallErrors::SCHEMA
    assert_equal "object", schema[:type]
    assert schema[:properties].key?(:since)
    assert schema[:properties].key?(:commit)
  end

  test "should return error and fatal logs" do
    # Create error and fatal logs
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "error",
      message: "Test error"
    )
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "fatal",
      message: "Test fatal"
    )
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test info (should not appear)"
    )

    result = @tool.call({})

    assert result.key?(:logs)
    result[:logs].each do |log|
      assert_includes %w[error fatal], log["level"]
    end
  end

  test "should use default since of 1h" do
    # Create old error (should not appear)
    @project.log_entries.create!(
      timestamp: 2.hours.ago,
      level: "error",
      message: "Old error"
    )

    result = @tool.call({})

    assert result.key?(:logs)
  end

  test "should filter by custom since" do
    result = @tool.call(since: "30m")

    assert result.key?(:logs)
  end

  test "should filter by commit" do
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "error",
      message: "Error with commit",
      commit: "specific_commit_123"
    )

    result = @tool.call(commit: "specific_commit_123")

    assert result.key?(:logs)
    result[:logs].each do |log|
      assert_equal "specific_commit_123", log["commit"]
    end
  end

  test "should combine since and commit filters" do
    result = @tool.call(since: "2h", commit: "abc123")

    assert result.key?(:logs)
  end

  test "should handle nil arguments" do
    result = @tool.call(since: nil, commit: nil)

    assert result.key?(:logs)
  end
end
