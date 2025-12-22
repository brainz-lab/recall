module Dashboard
  class LogsController < BaseController
    before_action :set_project

    def index
      @query = params[:q].to_s
      @offset = params[:offset].to_i
      @saved_searches = @project.saved_searches.ordered
      parser = QueryParser.new(@query).parse

      if parser.stats?
        @logs = parser.apply_stats(parser.apply(@project.log_entries))
        @has_more = false
      else
        base_query = parser.apply(@project.log_entries)
        @limit = parser.limit
        @logs = base_query.offset(@offset).limit(@limit)
        @has_more = base_query.offset(@offset + @limit).exists?
        @next_offset = @offset + @limit
      end

      # Get log counts by level for the last hour (matching filter buttons)
      @log_counts = @project.log_entries.recent_counts(since: 1.hour.ago)
      @log_counts_24h = @project.log_entries.recent_counts(since: 24.hours.ago)
      @total_logs = @project.logs_count

      # Disable caching for Turbo Frame requests
      response.headers["Cache-Control"] = "no-cache, no-store" if turbo_frame_request?

      # Render only the log rows partial for infinite scroll requests
      if params[:offset].present? && turbo_frame_request?
        render "load_more", layout: false
      end
    end

    def show
      @log = @project.log_entries.find(params[:id])
    end

    def trace
      @request_id = params[:request_id]
      @logs = @project.log_entries.where(request_id: @request_id).reorder(timestamp: :asc)

      if @logs.empty?
        redirect_to dashboard_project_logs_path(@project), alert: "No logs found for request #{@request_id}"
        return
      end

      @first_log = @logs.first
      @last_log = @logs.last
      @log_count = @logs.size
      @duration_ms = ((@last_log.timestamp - @first_log.timestamp) * 1000).round
      @levels = @logs.unscope(:order).group(:level).count
      @services = @logs.unscope(:order).where.not(service: nil).distinct.pluck(:service)
      @session_id = @first_log.session_id
    end

    def session_trace
      @session_id = params[:session_id]
      @logs = @project.log_entries.where(session_id: @session_id).reorder(timestamp: :asc)

      if @logs.empty?
        redirect_to dashboard_project_logs_path(@project), alert: "No logs found for session #{@session_id}"
        return
      end

      @first_log = @logs.first
      @last_log = @logs.last
      @log_count = @logs.size
      @duration_ms = ((@last_log.timestamp - @first_log.timestamp) * 1000).round
      @levels = @logs.unscope(:order).group(:level).count
      @services = @logs.unscope(:order).where.not(service: nil).distinct.pluck(:service)
      @request_ids = @logs.unscope(:order).where.not(request_id: nil).distinct.pluck(:request_id)
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end
  end
end
