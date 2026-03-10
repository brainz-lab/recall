module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate!
      after_action :set_trace_headers

      private

      def set_trace_headers
        response.headers["X-Request-Id"] = request.request_id
        response.headers["X-Runtime"] = "%.6f" % (Time.current - request_start_time) if request_start_time
      end

      def request_start_time
        @_request_start_time ||= Time.current
      end

      def authenticate!
        key = extract_key
        return render_unauthorized unless key.present?

        # Try local lookup first (fastest)
        @project = Project.find_by(api_key: key) || Project.find_by(ingest_key: key)
        return if @project

        # Fall back to Platform validation for sk_live_/sk_test_ keys
        if key.start_with?("sk_live_", "sk_test_")
          @project = validate_with_platform(key)
        end

        render_unauthorized unless @project
      end

      def validate_with_platform(key)
        result = PlatformClient.validate_key(key)
        return nil unless result.valid?

        # Create/sync local project from Platform
        PlatformClient.find_or_create_project(result, key)
      rescue StandardError => e
        Rails.logger.error "[BaseController] Platform validation error: #{e.message}"
        nil
      end

      def render_unauthorized
        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def extract_key
        request.headers["Authorization"]&.sub(/^Bearer\s+/, "") ||
        request.headers["X-API-Key"] ||
        params[:api_key]
      end

      def track_usage!(count = 1)
        return unless @project&.platform_project_id

        PlatformClient.track_usage(
          project_id: @project.platform_project_id,
          product: "recall",
          metric: "logs",
          count: count
        )
      end

      def track_bytes!(byte_count)
        return unless @project&.platform_project_id
        return unless byte_count.to_i > 0

        PlatformClient.track_usage(
          project_id: @project.platform_project_id,
          product: "recall",
          metric: "bytes",
          count: byte_count.to_i
        )
      end
    end
  end
end
