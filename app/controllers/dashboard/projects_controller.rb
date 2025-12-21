module Dashboard
  class ProjectsController < BaseController
    before_action :set_project, only: [:show, :edit, :update, :destroy, :setup, :mcp_setup, :analytics]

    def index
      @projects = Project.order(created_at: :desc)
    end

    def show
      redirect_to dashboard_project_logs_path(@project)
    end

    def new
      @project = Project.new
    end

    def create
      @project = Project.new(project_params)
      if @project.save
        redirect_to setup_dashboard_project_path(@project), notice: 'Project created! Follow the setup guide below.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def setup
    end

    def mcp_setup
    end

    def analytics
      # Time range from params, default to 7 days
      @range = params[:range] || "7d"
      @since = case @range
               when "24h" then 24.hours.ago
               when "7d" then 7.days.ago
               when "30d" then 30.days.ago
               else 7.days.ago
               end

      # Filters
      @level_filter = params[:level].presence
      @env_filter = params[:env].presence
      @service_filter = params[:service].presence

      # Base query with filters
      logs = @project.log_entries.unscope(:order).where("timestamp >= ?", @since)
      logs = logs.where(level: @level_filter) if @level_filter
      logs = logs.where(environment: @env_filter) if @env_filter
      logs = logs.where(service: @service_filter) if @service_filter

      # Available filter options (from all logs, not filtered)
      all_logs = @project.log_entries.unscope(:order).where("timestamp >= ?", @since)
      @available_levels = all_logs.distinct.pluck(:level).compact.sort
      @available_envs = all_logs.where.not(environment: nil).distinct.pluck(:environment).compact.sort
      @available_services = all_logs.where.not(service: nil).distinct.pluck(:service).compact.sort

      # Total counts
      @total_logs = logs.count
      @logs_by_level = logs.group(:level).count

      # Generate time series with all time slots
      @chart_data = generate_time_series(logs, @range, @since)
      @error_chart_data = generate_time_series(logs.where(level: %w[error fatal]), @range, @since)

      # Top error messages
      @top_errors = logs.where(level: %w[error fatal])
                        .group(:message)
                        .order("count_all DESC")
                        .limit(10)
                        .count

      # Logs by service (if available)
      @logs_by_service = logs.where.not(service: nil).group(:service).count

      # Logs by environment
      @logs_by_environment = logs.where.not(environment: nil).group(:environment).count
    end

    def update
      if @project.update(project_params)
        redirect_to dashboard_project_logs_path(@project), notice: 'Project updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @project.destroy
      redirect_to dashboard_projects_path, notice: 'Project deleted.'
    end

    private

    def set_project
      @project = Project.find(params[:id])
    end

    def project_params
      params.require(:project).permit(:name, :retention_days, :archive_enabled)
    end

    def generate_time_series(logs, range, since)
      now = Time.current

      if range == "24h"
        # Hourly buckets for 24h (from since to now)
        raw_data = logs.group("date_trunc('hour', timestamp)").count
        # Convert keys to comparable format
        data_by_hour = raw_data.transform_keys { |k| k&.strftime("%Y-%m-%d %H") }

        labels = []
        values = []
        current = since.beginning_of_hour
        while current <= now
          key = current.strftime("%Y-%m-%d %H")
          labels << current.strftime("%H:00")
          values << (data_by_hour[key] || 0)
          current += 1.hour
        end
      else
        # Daily buckets for 7d/30d (from since to today)
        raw_data = logs.group("date_trunc('day', timestamp)").count
        # Convert keys to comparable format
        data_by_day = raw_data.transform_keys { |k| k&.strftime("%Y-%m-%d") }

        labels = []
        values = []
        current = since.beginning_of_day
        today = now.beginning_of_day
        while current <= today
          key = current.strftime("%Y-%m-%d")
          labels << current.strftime("%b %d")
          values << (data_by_day[key] || 0)
          current += 1.day
        end
      end

      { labels: labels, values: values }
    end
  end
end
