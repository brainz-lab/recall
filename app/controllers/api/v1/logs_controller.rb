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

      # Signal integration: Query logs with aggregation for alerting
      def query
        log_level = params[:log_level] || 'error'
        aggregation = params[:aggregation] || 'count'
        window = parse_window(params[:window] || '5m')
        query_filters = JSON.parse(params[:query] || '{}')

        scope = @project.log_entries
                        .where('timestamp >= ?', window.ago)
                        .where(level: log_level)

        # Apply additional query filters
        query_filters.each do |key, value|
          case key
          when 'service' then scope = scope.where(service: value)
          when 'host' then scope = scope.where(host: value)
          when 'environment' then scope = scope.where(environment: value)
          end
        end

        value = case aggregation
                when 'count' then scope.count
                when 'avg', 'sum', 'min', 'max'
                  # For numeric aggregations on data fields
                  scope.count # Default to count for logs
                else
                  scope.count
                end

        render json: { value: value, log_level: log_level, window: params[:window] }
      end

      # Signal integration: Get baseline for anomaly detection
      def baseline
        log_level = params[:log_level] || 'error'
        window = parse_window(params[:window] || '24h')

        # Get hourly counts for the baseline window
        hourly_counts = @project.log_entries
                                .where('timestamp >= ?', window.ago)
                                .where(level: log_level)
                                .group("date_trunc('hour', timestamp)")
                                .count
                                .values

        if hourly_counts.empty?
          render json: { mean: 0, stddev: 1 }
        else
          mean = hourly_counts.sum.to_f / hourly_counts.size
          variance = hourly_counts.map { |c| (c - mean)**2 }.sum / hourly_counts.size
          stddev = Math.sqrt(variance)

          render json: { mean: mean, stddev: [stddev, 1].max }
        end
      end

      # Signal integration: Get last data point for absence detection
      def last
        log_level = params[:log_level] || 'error'
        query_filters = JSON.parse(params[:query] || '{}')

        scope = @project.log_entries.where(level: log_level)

        query_filters.each do |key, value|
          case key
          when 'service' then scope = scope.where(service: value)
          when 'host' then scope = scope.where(host: value)
          end
        end

        last_entry = scope.order(timestamp: :desc).first

        if last_entry
          render json: {
            timestamp: last_entry.timestamp.iso8601,
            value: 1,
            message: last_entry.message
          }
        else
          render json: { timestamp: nil, value: nil }
        end
      end

      private

      def parse_window(window_str)
        match = window_str&.match(/^(\d+)(m|h|d)$/)
        return 5.minutes unless match

        value = match[1].to_i
        case match[2]
        when 'm' then value.minutes
        when 'h' then value.hours
        when 'd' then value.days
        else 5.minutes
        end
      end
    end
  end
end
