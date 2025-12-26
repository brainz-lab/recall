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

        if entries.any?
          # Use raw SQL for bulk inserts to avoid Rails 8.1 unique index validation
          # which fails for TimescaleDB hypertables with composite primary keys
          bulk_insert_logs(entries)
          broadcast_batch(entries)
        end
        render json: { ingested: entries.size }, status: :created
      end

      private

      def log_params
        params.permit(:timestamp, :level, :message, :commit, :branch,
                      :environment, :service, :host, :request_id, :session_id, data: {})
              .reverse_merge(timestamp: Time.current, level: 'info')
      end

      def build_entry(log)
        # Convert ActionController::Parameters to hash and ensure data is JSON-serializable
        data = log[:data]
        data = data.to_unsafe_h if data.respond_to?(:to_unsafe_h)
        data = (data || {}).to_json

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
          data: data,
          created_at: Time.current
        }
      end

      def broadcast_log(entry)
        LogsChannel.broadcast_to(@project, { type: "log", log: entry.as_json })
      rescue => e
        Rails.logger.warn "Failed to broadcast log: #{e.message}"
      end

      def broadcast_batch(entries)
        entries.each do |entry|
          LogsChannel.broadcast_to(@project, { type: "log", log: entry })
        end
      rescue => e
        Rails.logger.warn "Failed to broadcast batch: #{e.message}"
      end

      def bulk_insert_logs(entries)
        return if entries.empty?

        columns = entries.first.keys
        values = entries.map do |entry|
          columns.map { |col| ActiveRecord::Base.connection.quote(entry[col]) }.join(", ")
        end

        sql = <<~SQL
          INSERT INTO log_entries (#{columns.join(', ')})
          VALUES #{values.map { |v| "(#{v})" }.join(', ')}
        SQL

        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
