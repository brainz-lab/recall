module Dashboard
  class SavedSearchesController < BaseController
    before_action :set_project
    before_action :set_saved_search, only: [:destroy]

    def index
      @saved_searches = @project.saved_searches.ordered
      respond_to do |format|
        format.html
        format.json { render json: @saved_searches }
      end
    end

    def create
      @saved_search = @project.saved_searches.build(saved_search_params)

      respond_to do |format|
        if @saved_search.save
          LogsChannel.broadcast_saved_search_created(@project, @saved_search)
          format.html { redirect_to dashboard_project_logs_path(@project, q: @saved_search.query), notice: "Search saved!" }
          format.json { render json: @saved_search, status: :created }
          format.turbo_stream
        else
          format.html { redirect_to dashboard_project_logs_path(@project), alert: @saved_search.errors.full_messages.join(", ") }
          format.json { render json: { errors: @saved_search.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      saved_search_id = @saved_search.id
      @saved_search.destroy
      LogsChannel.broadcast_saved_search_deleted(@project, saved_search_id)

      respond_to do |format|
        format.html { redirect_to dashboard_project_logs_path(@project), notice: "Search deleted." }
        format.json { head :no_content }
        format.turbo_stream
      end
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end

    def set_saved_search
      @saved_search = @project.saved_searches.find(params[:id])
    end

    def saved_search_params
      params.require(:saved_search).permit(:name, :query)
    end
  end
end
