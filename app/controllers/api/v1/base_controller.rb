module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate!

      private

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
    end
  end
end
