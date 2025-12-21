module Api
  module V1
    class IngestController < BaseController
      def create
        entry = @project.log_entries.create!(log_params)
        broadcast_log(entry)
        render json: { id: entry.id }, status: :created
      end

      def batch
        logs = params[:logs] || params[:_json] || []
        entries = logs.map { |l| build_entry(l) }.compact

        LogEntry.insert_all(entries) if entries.any?
        render json: { ingested: entries.size }, status: :created
      end

      private

      def log_params
        params.permit(:timestamp, :level, :message, :commit, :branch,
                      :environment, :service, :host, :request_id, :session_id, data: {})
              .reverse_merge(timestamp: Time.current, level: 'info')
      end

      def build_entry(log)
        {
          id: SecureRandom.uuid,
          project_id: @project.id,
          timestamp: log[:timestamp] || Time.current,
          level: log[:level] || 'info',
          message: log[:message],
          commit: log[:commit],
          branch: log[:branch],
          environment: log[:environment],
          service: log[:service],
          host: log[:host],
          request_id: log[:request_id],
          session_id: log[:session_id],
          data: log[:data] || {},
          created_at: Time.current
        }
      end

      def broadcast_log(entry)
        LogsChannel.broadcast_to(@project, entry.as_json) if defined?(LogsChannel)
      rescue => e
        Rails.logger.warn "Failed to broadcast log: #{e.message}"
      end
    end
  end
end
