class LogArchiver
  attr_reader :project, :archived_count, :export_path

  def initialize(project)
    @project = project
    @archived_count = 0
    @export_path = nil
  end

  def archive!(export_before_delete: false)
    return { success: false, error: 'Archive not enabled' } unless project.archive_enabled?
    return { success: false, error: 'No retention policy set' } unless project.retention_days.present?

    logs_to_archive = deletable_logs

    if logs_to_archive.none?
      return { success: true, archived_count: 0, message: 'No logs to archive' }
    end

    # Export before delete if requested
    if export_before_delete
      @export_path = export_logs(logs_to_archive)
    end

    # Delete old logs in batches to avoid memory issues
    @archived_count = delete_in_batches(logs_to_archive)

    # Update project's last_archived_at
    project.update!(last_archived_at: Time.current)

    {
      success: true,
      archived_count: @archived_count,
      export_path: @export_path,
      message: "Archived #{@archived_count} logs"
    }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def deletable_logs
    cutoff_date = project.retention_days.days.ago
    project.log_entries.where('timestamp < ?', cutoff_date)
  end

  def deletable_count
    deletable_logs.count
  end

  def preview
    {
      retention_days: project.retention_days,
      cutoff_date: project.retention_days.days.ago,
      logs_to_archive: deletable_count,
      last_archived_at: project.last_archived_at
    }
  end

  private

  def export_logs(scope)
    # Create exports directory if it doesn't exist
    exports_dir = Rails.root.join('tmp', 'exports')
    FileUtils.mkdir_p(exports_dir)

    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = "#{project.name.parameterize}_archive_#{timestamp}.json"
    filepath = exports_dir.join(filename)

    # Export to file
    File.open(filepath, 'w') do |file|
      file.write("[\n")
      first = true
      scope.find_each do |log|
        file.write(",\n") unless first
        file.write(log.to_json)
        first = false
      end
      file.write("\n]")
    end

    filepath.to_s
  end

  def delete_in_batches(scope, batch_size: 1000)
    total_deleted = 0

    loop do
      # Delete in batches using subquery
      deleted = scope.limit(batch_size).delete_all
      total_deleted += deleted
      break if deleted < batch_size
    end

    # Update project logs_count
    project.update_column(:logs_count, project.log_entries.count)

    total_deleted
  end
end
