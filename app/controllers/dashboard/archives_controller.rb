module Dashboard
  class ArchivesController < BaseController
    before_action :set_project

    def show
      @archiver = LogArchiver.new(@project)
      @preview = @archiver.preview
    end

    def create
      archiver = LogArchiver.new(@project)

      if @project.archive_enabled?
        result = archiver.archive!(export_before_delete: params[:export_before_delete] == '1')

        if result[:success]
          redirect_to dashboard_project_archive_path(@project),
                      notice: result[:message]
        else
          redirect_to dashboard_project_archive_path(@project),
                      alert: result[:error]
        end
      else
        redirect_to dashboard_project_archive_path(@project),
                    alert: 'Archive is not enabled for this project'
      end
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end
  end
end
