require "test_helper"

class Dashboard::ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
  end

  # Index action
  test "should get index" do
    get dashboard_projects_url

    assert_response :success
  end

  test "should list all projects" do
    get dashboard_projects_url

    assert_response :success
    assert_select "body"
  end

  # Show action
  test "should redirect show to logs" do
    get dashboard_project_url(@project)

    assert_redirected_to dashboard_project_logs_path(@project)
  end

  # New action
  test "should get new" do
    get new_dashboard_project_url

    assert_response :success
  end

  # Create action
  test "should create project" do
    assert_difference("Project.count") do
      post dashboard_projects_url, params: {
        project: { name: "New Test Project", retention_days: 30 }
      }
    end

    project = Project.last
    assert_redirected_to setup_dashboard_project_path(project)
  end

  test "should not create project with invalid params" do
    assert_no_difference("Project.count") do
      post dashboard_projects_url, params: {
        project: { name: "", retention_days: 30 }
      }
    end

    assert_response :unprocessable_entity
  end

  # Edit action
  test "should get edit" do
    get edit_dashboard_project_url(@project)

    assert_response :success
  end

  # Setup action
  test "should get setup" do
    get setup_dashboard_project_url(@project)

    assert_response :success
  end

  # MCP Setup action
  test "should get mcp_setup" do
    get mcp_setup_dashboard_project_url(@project)

    assert_response :success
  end

  # Analytics action
  test "should get analytics" do
    get analytics_dashboard_project_url(@project)

    assert_response :success
  end

  test "should get analytics with 24h range" do
    get analytics_dashboard_project_url(@project, range: "24h")

    assert_response :success
  end

  test "should get analytics with 7d range" do
    get analytics_dashboard_project_url(@project, range: "7d")

    assert_response :success
  end

  test "should get analytics with 30d range" do
    get analytics_dashboard_project_url(@project, range: "30d")

    assert_response :success
  end

  test "should get analytics with level filter" do
    get analytics_dashboard_project_url(@project, level: "error")

    assert_response :success
  end

  test "should get analytics with env filter" do
    get analytics_dashboard_project_url(@project, env: "production")

    assert_response :success
  end

  test "should get analytics with service filter" do
    get analytics_dashboard_project_url(@project, service: "web")

    assert_response :success
  end

  test "should get analytics with multiple filters" do
    get analytics_dashboard_project_url(@project,
      range: "24h",
      level: "error",
      env: "production",
      service: "api"
    )

    assert_response :success
  end

  # Update action
  test "should update project" do
    patch dashboard_project_url(@project), params: {
      project: { name: "Updated Name" }
    }

    assert_redirected_to dashboard_project_logs_path(@project)
    @project.reload
    assert_equal "Updated Name", @project.name
  end

  test "should update project retention_days" do
    patch dashboard_project_url(@project), params: {
      project: { retention_days: 60 }
    }

    assert_redirected_to dashboard_project_logs_path(@project)
    @project.reload
    assert_equal 60, @project.retention_days
  end

  test "should update project archive_enabled" do
    patch dashboard_project_url(@project), params: {
      project: { archive_enabled: true }
    }

    assert_redirected_to dashboard_project_logs_path(@project)
    @project.reload
    assert @project.archive_enabled
  end

  test "should not update project with invalid params" do
    patch dashboard_project_url(@project), params: {
      project: { name: "" }
    }

    assert_response :unprocessable_entity
  end

  # Destroy action
  test "should destroy project" do
    assert_difference("Project.count", -1) do
      delete dashboard_project_url(@project)
    end

    assert_redirected_to dashboard_projects_path
  end
end
