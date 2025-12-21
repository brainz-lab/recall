class ArchiveLogsJob < ApplicationJob
  queue_as :default

  def perform(project_id = nil)
    if project_id
      # Archive specific project
      project = Project.find(project_id)
      archive_project(project)
    else
      # Archive all projects with archiving enabled
      Project.where(archive_enabled: true).find_each do |project|
        archive_project(project)
      end
    end
  end

  private

  def archive_project(project)
    archiver = LogArchiver.new(project)
    result = archiver.archive!(export_before_delete: false)

    if result[:success]
      Rails.logger.info "[ArchiveLogsJob] Project #{project.name}: #{result[:message]}"
    else
      Rails.logger.error "[ArchiveLogsJob] Project #{project.name}: #{result[:error]}"
    end
  rescue StandardError => e
    Rails.logger.error "[ArchiveLogsJob] Project #{project.name} failed: #{e.message}"
  end
end
