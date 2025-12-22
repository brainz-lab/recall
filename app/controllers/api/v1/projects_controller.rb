# frozen_string_literal: true

module Api
  module V1
    class ProjectsController < ActionController::API
      before_action :authenticate_master_key!

      # POST /api/v1/projects/provision
      # Creates a new project or returns existing one
      def provision
        project = Project.find_or_create_by!(name: params[:name])

        render json: {
          name: project.name,
          slug: project.slug,
          ingest_key: project.ingest_key,
          api_key: project.api_key
        }
      end

      # GET /api/v1/projects/lookup
      # Looks up a project by name or slug
      def lookup
        project = Project.find_by(name: params[:name]) || Project.find_by(slug: params[:name])

        if project
          render json: {
            name: project.name,
            slug: project.slug,
            ingest_key: project.ingest_key,
            api_key: project.api_key
          }
        else
          render json: { error: "Project not found" }, status: :not_found
        end
      end

      private

      def authenticate_master_key!
        key = request.headers["X-Master-Key"]
        expected = ENV["RECALL_MASTER_KEY"]

        return if key.present? && expected.present? && ActiveSupport::SecurityUtils.secure_compare(key, expected)

        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
