module Api
  module V1
    class SessionsController < BaseController
      # GET /api/v1/sessions
      def index
        sessions = @project.log_entries
          .where.not(session_id: nil)
          .select(:session_id)
          .distinct
          .order(Arel.sql("MAX(timestamp) DESC"))
          .group(:session_id)
          .limit(params[:limit] || 50)

        session_stats = sessions.map do |entry|
          logs = @project.log_entries.where(session_id: entry.session_id)
          {
            session_id: entry.session_id,
            log_count: logs.count,
            first_log: logs.minimum(:timestamp),
            last_log: logs.maximum(:timestamp),
            levels: logs.group(:level).count
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
          levels: logs.group(:level).count,
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
