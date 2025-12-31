require "test_helper"

class Dashboard::ExportsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
  end

  # Create action (export)
  test "should export as json" do
    post dashboard_project_exports_url(@project, format: "json")

    assert_response :success
    assert_equal "application/json", response.content_type.split(";").first
    assert response.headers["Content-Disposition"].include?("attachment")
  end

  test "should export as csv" do
    post dashboard_project_exports_url(@project, format: "csv")

    assert_response :success
    assert_equal "text/csv", response.content_type.split(";").first
    assert response.headers["Content-Disposition"].include?("attachment")
  end

  test "should export with query filter" do
    post dashboard_project_exports_url(@project, format: "json", q: "level:info")

    assert_response :success
    json = JSON.parse(response.body)
    json.each do |log|
      assert_equal "info", log["level"]
    end
  end

  test "should export with since filter" do
    post dashboard_project_exports_url(@project, format: "json", since: "1h")

    assert_response :success
  end

  test "should export with until filter" do
    post dashboard_project_exports_url(@project, format: "json", until: "30m")

    assert_response :success
  end

  test "should export with combined filters" do
    post dashboard_project_exports_url(@project,
      format: "json",
      q: "level:error",
      since: "24h"
    )

    assert_response :success
  end

  test "should default to json for invalid format" do
    post dashboard_project_exports_url(@project, format: "invalid")

    assert_response :success
    assert_equal "application/json", response.content_type.split(";").first
  end

  test "should include filename in content disposition" do
    post dashboard_project_exports_url(@project, format: "json")

    disposition = response.headers["Content-Disposition"]
    assert disposition.include?("filename")
    assert disposition.include?(".json")
  end

  test "csv export should include headers" do
    post dashboard_project_exports_url(@project, format: "csv")

    csv_content = response.body
    first_line = csv_content.lines.first
    assert first_line.include?("timestamp")
    assert first_line.include?("level")
    assert first_line.include?("message")
  end
end
