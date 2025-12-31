require "test_helper"

class Dashboard::SavedSearchesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @saved_search = @project.saved_searches.create!(name: "Test Search", query: "level:error")
  end

  # Index action
  test "should get index html" do
    get dashboard_project_saved_searches_url(@project)

    assert_response :success
  end

  test "should get index json" do
    get dashboard_project_saved_searches_url(@project), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
  end

  # Create action
  test "should create saved search html" do
    assert_difference("SavedSearch.count") do
      post dashboard_project_saved_searches_url(@project), params: {
        saved_search: { name: "New Search", query: "level:warn" }
      }
    end

    assert_redirected_to dashboard_project_logs_path(@project, q: "level:warn")
  end

  test "should create saved search json" do
    assert_difference("SavedSearch.count") do
      post dashboard_project_saved_searches_url(@project), params: {
        saved_search: { name: "New Search", query: "level:warn" }
      }, as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New Search", json["name"]
    assert_equal "level:warn", json["query"]
  end

  test "should create saved search turbo_stream" do
    assert_difference("SavedSearch.count") do
      post dashboard_project_saved_searches_url(@project), params: {
        saved_search: { name: "Turbo Search", query: "level:info" }
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
  end

  test "should not create saved search with invalid params html" do
    assert_no_difference("SavedSearch.count") do
      post dashboard_project_saved_searches_url(@project), params: {
        saved_search: { name: "", query: "level:error" }
      }
    end

    assert_redirected_to dashboard_project_logs_path(@project)
  end

  test "should not create saved search with invalid params json" do
    assert_no_difference("SavedSearch.count") do
      post dashboard_project_saved_searches_url(@project), params: {
        saved_search: { name: "", query: "level:error" }
      }, as: :json
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json.key?("errors")
  end

  # Destroy action
  test "should destroy saved search html" do
    assert_difference("SavedSearch.count", -1) do
      delete dashboard_project_saved_search_url(@project, @saved_search)
    end

    assert_redirected_to dashboard_project_logs_path(@project)
  end

  test "should destroy saved search json" do
    assert_difference("SavedSearch.count", -1) do
      delete dashboard_project_saved_search_url(@project, @saved_search), as: :json
    end

    assert_response :no_content
  end

  test "should destroy saved search turbo_stream" do
    assert_difference("SavedSearch.count", -1) do
      delete dashboard_project_saved_search_url(@project, @saved_search),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
  end

  test "should not destroy saved search from other project" do
    other_project = projects(:two)
    other_search = other_project.saved_searches.create!(name: "Other", query: "test")

    assert_raises(ActiveRecord::RecordNotFound) do
      delete dashboard_project_saved_search_url(@project, other_search)
    end
  end
end
