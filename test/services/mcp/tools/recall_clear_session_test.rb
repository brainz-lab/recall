require "test_helper"

class Mcp::Tools::RecallClearSessionTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @tool = Mcp::Tools::RecallClearSession.new(@project)
  end

  test "should have description" do
    assert Mcp::Tools::RecallClearSession::DESCRIPTION.present?
    assert_includes Mcp::Tools::RecallClearSession::DESCRIPTION, "session"
  end

  test "should have schema with session_id required" do
    schema = Mcp::Tools::RecallClearSession::SCHEMA
    assert_equal "object", schema[:type]
    assert schema[:properties].key?(:session_id)
    assert_includes schema[:required], "session_id"
  end

  test "should return deleted count and session_id" do
    result = @tool.call(session_id: "sess_nonexistent")

    assert result.key?(:deleted)
    assert result.key?(:session_id)
  end

  test "should delete logs for specified session" do
    # Create logs for a specific session
    session_id = "sess_to_delete_#{SecureRandom.hex(4)}"
    3.times do |i|
      @project.log_entries.create!(
        timestamp: Time.current - i.minutes,
        level: "info",
        message: "Log #{i}",
        session_id: session_id
      )
    end

    result = @tool.call(session_id: session_id)

    assert_equal 3, result[:deleted]
    assert_equal session_id, result[:session_id]
  end

  test "should not delete logs from other sessions" do
    session_to_keep = "sess_keep_#{SecureRandom.hex(4)}"
    session_to_delete = "sess_delete_#{SecureRandom.hex(4)}"

    @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Keep this",
      session_id: session_to_keep
    )
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Delete this",
      session_id: session_to_delete
    )

    @tool.call(session_id: session_to_delete)

    # Verify the kept session log still exists
    remaining = @project.log_entries.where(session_id: session_to_keep)
    assert_equal 1, remaining.count
  end

  test "should return zero for nonexistent session" do
    result = @tool.call(session_id: "sess_does_not_exist_123")

    assert_equal 0, result[:deleted]
  end

  test "should not affect other projects" do
    other_project = projects(:two)
    session_id = "sess_shared_#{SecureRandom.hex(4)}"

    # Create log in other project with same session_id
    other_project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Other project log",
      session_id: session_id
    )

    # Create log in this project with same session_id
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "This project log",
      session_id: session_id
    )

    # Clear session in this project
    result = @tool.call(session_id: session_id)

    assert_equal 1, result[:deleted]

    # Verify other project's log still exists
    assert_equal 1, other_project.log_entries.where(session_id: session_id).count
  end
end
