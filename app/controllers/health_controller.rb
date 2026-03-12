class HealthController < ActionController::API
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: "ok", db: "connected" }
  rescue => e
    render json: { status: "degraded", db: "disconnected", error: e.message }, status: :service_unavailable
  end
end
