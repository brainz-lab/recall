require "test_helper"

class LogArchiverTest < ActiveSupport::TestCase
  def setup
    @project = projects(:archived)
    @archiver = LogArchiver.new(@project)
  end

  def teardown
    # Clean up any export files created during tests
    exports_dir = Rails.root.join("tmp", "exports")
    FileUtils.rm_rf(exports_dir) if File.exist?(exports_dir)
  end

  # Initialization
  test "should initialize with project" do
    assert_equal @project, @archiver.project
  end

  test "should initialize with zero archived_count" do
    assert_equal 0, @archiver.archived_count
  end

  test "should initialize with nil export_path" do
    assert_nil @archiver.export_path
  end

  # Archive validation
  test "should fail if archive not enabled" do
    project = projects(:one)
    project.update!(archive_enabled: false)
    archiver = LogArchiver.new(project)

    result = archiver.archive!
    assert_equal false, result[:success]
    assert_equal "Archive not enabled", result[:error]
  end

  test "should fail if retention_days not set" do
    @project.update!(retention_days: nil)
    result = @archiver.archive!

    assert_equal false, result[:success]
    assert_equal "No retention policy set", result[:error]
  end

  # Deletable logs
  test "deletable_logs should return logs older than retention period" do
    # Create old log
    old_log = @project.log_entries.create!(
      timestamp: (@project.retention_days + 1).days.ago,
      level: "info",
      message: "Old log"
    )

    deletable = @archiver.deletable_logs
    assert_includes deletable.pluck(:id), old_log.id
  end

  test "deletable_logs should not include recent logs" do
    # Create recent log
    recent_log = @project.log_entries.create!(
      timestamp: 1.day.ago,
      level: "info",
      message: "Recent log"
    )

    deletable = @archiver.deletable_logs
    assert_not_includes deletable.pluck(:id), recent_log.id
  end

  test "deletable_count should return count of old logs" do
    count_before = @archiver.deletable_count

    # Create old log
    @project.log_entries.create!(
      timestamp: (@project.retention_days + 1).days.ago,
      level: "info",
      message: "Old log"
    )

    assert_equal count_before + 1, @archiver.deletable_count
  end

  # Preview
  test "preview should return retention information" do
    preview = @archiver.preview

    assert preview.key?(:retention_days)
    assert preview.key?(:cutoff_date)
    assert preview.key?(:logs_to_archive)
    assert preview.key?(:last_archived_at)
  end

  test "preview should show correct retention_days" do
    preview = @archiver.preview
    assert_equal @project.retention_days, preview[:retention_days]
  end

  test "preview should calculate correct cutoff_date" do
    preview = @archiver.preview
    expected = @project.retention_days.days.ago

    # Allow 1 second difference due to time calculation
    assert_in_delta expected.to_i, preview[:cutoff_date].to_i, 1
  end

  test "preview should show logs_to_archive count" do
    preview = @archiver.preview
    assert_equal @archiver.deletable_count, preview[:logs_to_archive]
  end

  # Archiving without export
  test "should archive old logs without export" do
    # Create old log
    old_log = @project.log_entries.create!(
      timestamp: (@project.retention_days + 1).days.ago,
      level: "info",
      message: "To be archived"
    )

    result = @archiver.archive!(export_before_delete: false)

    assert result[:success]
    assert result[:archived_count] > 0
    assert_nil result[:export_path]
    assert_not LogEntry.exists?(old_log.id)
  end

  test "should return success with no logs to archive" do
    # Delete all old logs first
    @archiver.deletable_logs.delete_all

    result = @archiver.archive!

    assert result[:success]
    assert_equal 0, result[:archived_count]
    assert_equal "No logs to archive", result[:message]
  end

  test "should update last_archived_at timestamp" do
    # Create old log
    @project.log_entries.create!(
      timestamp: (@project.retention_days + 1).days.ago,
      level: "info",
      message: "To be archived"
    )

    original_time = @project.last_archived_at

    @archiver.archive!
    @project.reload

    assert @project.last_archived_at > original_time
  end

  # Archiving with export
  test "should export logs before deleting when requested" do
    # Create old log
    @project.log_entries.create!(
      timestamp: (@project.retention_days + 1).days.ago,
      level: "info",
      message: "To be archived and exported"
    )

    result = @archiver.archive!(export_before_delete: true)

    assert result[:success]
    assert_not_nil result[:export_path]
    assert File.exist?(result[:export_path])
  end

  test "exported file should contain valid json" do
    # Create old log
    @project.log_entries.create!(
      timestamp: (@project.retention_days + 1).days.ago,
      level: "info",
      message: "To be exported"
    )

    result = @archiver.archive!(export_before_delete: true)

    assert File.exist?(result[:export_path])
    content = File.read(result[:export_path])

    assert_nothing_raised do
      JSON.parse(content)
    end
  end

  test "exported file should include archived logs" do
    # Create old log
    old_log = @project.log_entries.create!(
      timestamp: (@project.retention_days + 1).days.ago,
      level: "info",
      message: "To be exported"
    )

    result = @archiver.archive!(export_before_delete: true)

    content = File.read(result[:export_path])
    logs = JSON.parse(content)

    assert logs.any? { |l| l["message"] == "To be exported" }
  end

  test "export filename should include project name and timestamp" do
    # Create old log
    @project.log_entries.create!(
      timestamp: (@project.retention_days + 1).days.ago,
      level: "info",
      message: "To be archived"
    )

    result = @archiver.archive!(export_before_delete: true)

    filename = File.basename(result[:export_path])
    assert_includes filename, @project.name.parameterize
    assert_includes filename, "archive"
    assert_match /\d{8}_\d{6}/, filename
    assert_match /\.json$/, filename
  end

  # Batch deletion
  test "should delete logs in batches to avoid memory issues" do
    # Create multiple old logs
    10.times do |i|
      @project.log_entries.create!(
        timestamp: (@project.retention_days + 1).days.ago,
        level: "info",
        message: "Batch test #{i}"
      )
    end

    initial_count = @archiver.deletable_count
    result = @archiver.archive!

    assert result[:success]
    assert_equal initial_count, result[:archived_count]
    assert_equal 0, @archiver.deletable_count
  end

  # Error handling
  test "should handle errors gracefully" do
    # Force an error by stubbing delete_all to raise
    @archiver.stub :delete_in_batches, -> (*args) { raise "Test error" } do
      # Create old log
      @project.log_entries.create!(
        timestamp: (@project.retention_days + 1).days.ago,
        level: "info",
        message: "To cause error"
      )

      result = @archiver.archive!

      assert_equal false, result[:success]
      assert_equal "Test error", result[:error]
    end
  end

  test "should update project logs_count after archiving" do
    # Create old logs
    3.times do
      @project.log_entries.create!(
        timestamp: (@project.retention_days + 1).days.ago,
        level: "info",
        message: "To be archived"
      )
    end

    @archiver.archive!
    @project.reload

    # logs_count should reflect current count
    assert_equal @project.log_entries.count, @project.logs_count
  end

  # Integration
  test "full archive workflow with export and deletion" do
    # Setup: Create mix of old and recent logs
    old_logs = 5.times.map do |i|
      @project.log_entries.create!(
        timestamp: (@project.retention_days + 1).days.ago,
        level: "info",
        message: "Old log #{i}"
      )
    end

    recent_logs = 3.times.map do |i|
      @project.log_entries.create!(
        timestamp: 1.day.ago,
        level: "info",
        message: "Recent log #{i}"
      )
    end

    # Archive with export
    result = @archiver.archive!(export_before_delete: true)

    # Verify results
    assert result[:success]
    assert_equal 5, result[:archived_count]
    assert_not_nil result[:export_path]
    assert File.exist?(result[:export_path])

    # Verify old logs deleted
    old_logs.each do |log|
      assert_not LogEntry.exists?(log.id)
    end

    # Verify recent logs preserved
    recent_logs.each do |log|
      assert LogEntry.exists?(log.id)
    end

    # Verify export contains old logs
    content = File.read(result[:export_path])
    exported = JSON.parse(content)
    assert_equal 5, exported.size
  end
end
