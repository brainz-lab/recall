module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate!

      private

      def authenticate!
        key = extract_key
        @project = Project.find_by(api_key: key) || Project.find_by(ingest_key: key)
        render json: { error: 'Unauthorized' }, status: :unauthorized unless @project
      end

      def extract_key
        request.headers['Authorization']&.sub(/^Bearer\s+/, '') ||
        request.headers['X-API-Key'] ||
        params[:api_key]
      end
    end
  end
end
