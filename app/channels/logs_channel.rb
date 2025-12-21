class LogsChannel < ApplicationCable::Channel
  # Live tail - streams new logs to the dashboard
  def subscribed
    project = Project.find(params[:project_id])
    stream_for project
  end

  def unsubscribed
    stop_all_streams
  end
end
