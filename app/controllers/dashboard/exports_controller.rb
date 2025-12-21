module Dashboard
  class ExportsController < BaseController
    before_action :set_project

    def create
      exporter = LogExporter.new(
        @project,
        query: params[:q],
        since: params[:since],
        until_time: params[:until],
        format: export_format
      )

      send_data exporter.export,
                filename: exporter.filename,
                type: exporter.content_type,
                disposition: 'attachment'
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end

    def export_format
      %w[json csv].include?(params[:format]) ? params[:format] : 'json'
    end
  end
end
