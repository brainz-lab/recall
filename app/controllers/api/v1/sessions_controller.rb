module Api
  module V1
    class SessionsController < BaseController
      def create
        render json: { session_id: "sess_#{SecureRandom.hex(12)}" }, status: :created
      end

      def destroy
        deleted = @project.log_entries.where(session_id: params[:id]).delete_all
        render json: { deleted: deleted, session_id: params[:id] }
      end
    end
  end
end
