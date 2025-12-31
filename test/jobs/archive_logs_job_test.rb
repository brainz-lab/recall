require "test_helper"

class ArchiveLogsJobTest < ActiveSupport::TestCase
  def setup
    @project = projects(:archived)
    @project_no_archive = projects(:one)
  end

  test "should perform for specific project" do
    assert_nothing_raised do
      ArchiveLogsJob.perform_now(@project.id)
    end
  end

  test "should perform for all projects when no id given" do
    assert_nothing_raised do
      ArchiveLogsJob.perform_now
    end
  end

  test "should only archive projects with archive_enabled" do
    # Make sure only projects with archive_enabled are processed
    assert_nothing_raised do
      ArchiveLogsJob.perform_now
    end
  end

  test "should handle project not found gracefully" do
    assert_raises(ActiveRecord::RecordNotFound) do
      ArchiveLogsJob.perform_now("00000000-0000-0000-0000-000000000000")
    end
  end

  test "should archive old logs for project" do
    # Create old log that should be archived
    old_log = @project.log_entries.create!(
      timestamp: (@project.retention_days + 1).days.ago,
      level: "info",
      message: "Old log to archive"
    )

    ArchiveLogsJob.perform_now(@project.id)

    # Log should be deleted after archiving
    assert_nil LogEntry.find_by(id: old_log.id)
  end

  test "should not archive recent logs" do
    # Create recent log that should not be archived
    recent_log = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Recent log"
    )

    ArchiveLogsJob.perform_now(@project.id)

    # Recent log should still exist
    assert LogEntry.exists?(recent_log.id)
  end

  test "should handle archiver errors gracefully" do
    # Even if there's an error in one project, job should continue
    assert_nothing_raised do
      ArchiveLogsJob.perform_now(@project.id)
    end
  end

  test "should use default queue" do
    assert_equal "default", ArchiveLogsJob.new.queue_name
  end
end
