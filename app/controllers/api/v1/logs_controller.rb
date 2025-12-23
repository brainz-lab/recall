module Api
  module V1
    class LogsController < BaseController
      def index
        query = params[:q].to_s
        parser = QueryParser.new(query).parse
        scope = @project.log_entries

        if parser.stats?
          render json: { stats: parser.apply_stats(parser.apply(scope)), query: query }
        else
          limit = (params[:limit] || parser.limit).to_i.clamp(1, 1000)
          logs = parser.apply(scope).limit(limit)
          render json: { logs: logs, count: logs.size, query: query }
        end
      end

      def show
        log = @project.log_entries.find_by_composite_key(params[:id])
        render json: log
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Not found' }, status: :not_found
      end

      def export
        format = %w[json csv].include?(params[:format]) ? params[:format] : 'json'
        exporter = LogExporter.new(
          @project,
          query: params[:q],
          since: params[:since],
          until_time: params[:until],
          format: format
        )

        send_data exporter.export,
                  filename: exporter.filename,
                  type: exporter.content_type,
                  disposition: 'attachment'
      end
    end
  end
end
