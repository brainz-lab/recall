require "test_helper"

class Dashboard::ArchivesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:archived)
    @project_no_archive = projects(:one)
  end

  # Show action
  test "should get show" do
    get dashboard_project_archive_url(@project)

    assert_response :success
  end

  test "should get show for project without archiving" do
    get dashboard_project_archive_url(@project_no_archive)

    assert_response :success
  end

  # Create action (trigger archive)
  test "should archive logs when archive enabled" do
    post dashboard_project_archive_url(@project)

    assert_redirected_to dashboard_project_archive_path(@project)
  end

  test "should archive with export option" do
    post dashboard_project_archive_url(@project), params: {
      export_before_delete: "1"
    }

    assert_redirected_to dashboard_project_archive_path(@project)
  end

  test "should not archive when archive disabled" do
    post dashboard_project_archive_url(@project_no_archive)

    assert_redirected_to dashboard_project_archive_path(@project_no_archive)
    assert_match /not enabled/, flash[:alert]
  end

  test "should handle archive with no deletable logs" do
    # Delete all old logs first
    @project.log_entries.where("timestamp < ?", @project.retention_days.days.ago).delete_all

    post dashboard_project_archive_url(@project)

    assert_redirected_to dashboard_project_archive_path(@project)
  end
end
