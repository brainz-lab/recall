module Api
  module V1
    class SessionsController < BaseController
      # GET /api/v1/sessions
      def index
        limit = (params[:limit] || 50).to_i

        session_rows = @project.log_entries
          .where.not(session_id: nil)
          .group(:session_id)
          .select(
            "session_id",
            "COUNT(*) as log_count",
            "MIN(timestamp) as first_log",
            "MAX(timestamp) as last_log"
          )
          .order(Arel.sql("MAX(timestamp) DESC"))
          .limit(limit)

        session_ids = session_rows.map(&:session_id)

        # Single query for all level counts across all sessions (replaces N+1)
        level_counts = @project.log_entries
          .where(session_id: session_ids)
          .group(:session_id, :level)
          .count

        # Reshape {[session_id, level] => count} into {session_id => {level => count}}
        levels_by_session = level_counts.each_with_object({}) do |((sid, level), count), hash|
          hash[sid] ||= {}
          hash[sid][level] = count
        end

        session_stats = session_rows.map do |row|
          {
            session_id: row.session_id,
            log_count: row.log_count,
            first_log: row.first_log,
            last_log: row.last_log,
            levels: levels_by_session[row.session_id] || {}
          }
        end

        render json: { sessions: session_stats }
      end

      # GET /api/v1/sessions/:id
      def show
        logs = @project.log_entries.where(session_id: params[:id]).order(timestamp: :asc)

        if logs.empty?
          render json: { error: "Session not found" }, status: :not_found
          return
        end

        render json: {
          session_id: params[:id],
          log_count: logs.count,
          first_log: logs.first.timestamp,
          last_log: logs.last.timestamp,
          levels: logs.unscope(:order).group(:level).count,
          logs: logs.limit(100).as_json
        }
      end

      # GET /api/v1/sessions/:id/logs
      def logs
        logs = @project.log_entries.where(session_id: params[:id]).order(timestamp: :asc)

        if params[:level].present?
          logs = logs.where(level: params[:level])
        end

        logs = logs.limit(params[:limit] || 500)

        render json: {
          session_id: params[:id],
          count: logs.count,
          logs: logs.as_json
        }
      end

      # POST /api/v1/sessions
      def create
        render json: { session_id: "sess_#{SecureRandom.hex(12)}" }, status: :created
      end

      # DELETE /api/v1/sessions/:id
      def destroy
        session_id = params[:id]
        deleted = @project.log_entries.where(session_id: session_id).delete_all
        LogsChannel.broadcast_session_cleared(@project, session_id, deleted)
        render json: { deleted: deleted, session_id: session_id }
      end
    end
  end
end
