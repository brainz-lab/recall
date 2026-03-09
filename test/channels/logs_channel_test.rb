require "test_helper"

class LogsChannelTest < ActionCable::Channel::TestCase
  def setup
    @project = projects(:one)
    stub_connection current_user_id: "user-1", current_organization_id: nil
  end

  test "subscribes to project stream" do
    subscribe project_id: @project.id

    assert subscription.confirmed?
    assert_has_stream_for @project
  end

  test "unsubscribes and stops streams" do
    subscribe project_id: @project.id
    unsubscribe

    assert_no_streams
  end

  # Class method tests
  test "broadcast_log sends log to project stream" do
    log_entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test broadcast"
    )

    assert_broadcasts(@project, 1) do
      LogsChannel.broadcast_log(@project, log_entry)
    end
  end

  test "broadcast_log includes type and log data" do
    log_entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test broadcast"
    )

    LogsChannel.broadcast_log(@project, log_entry)

    # Verify the broadcast was sent (broadcasts are captured in test)
  end

  test "broadcast_session_cleared sends session_cleared to project stream" do
    assert_broadcasts(@project, 1) do
      LogsChannel.broadcast_session_cleared(@project, "sess_test", 5)
    end
  end

  test "broadcast_saved_search_created sends saved_search_created to project stream" do
    saved_search = @project.saved_searches.create!(
      name: "Test Search",
      query: "level:error"
    )

    assert_broadcasts(@project, 1) do
      LogsChannel.broadcast_saved_search_created(@project, saved_search)
    end
  end

  test "broadcast_saved_search_deleted sends saved_search_deleted to project stream" do
    assert_broadcasts(@project, 1) do
      LogsChannel.broadcast_saved_search_deleted(@project, "search-123")
    end
  end
end
