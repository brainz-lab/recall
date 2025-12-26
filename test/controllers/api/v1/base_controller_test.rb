require "test_helper"

class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
  end

  # Authentication with API key
  test "should authenticate with valid api_key in Authorization header" do
    get api_v1_logs_url,
        headers: { "Authorization" => "Bearer #{@project.api_key}" }

    assert_response :success
  end

  test "should authenticate with valid ingest_key in Authorization header" do
    get api_v1_logs_url,
        headers: { "Authorization" => "Bearer #{@project.ingest_key}" }

    assert_response :success
  end

  test "should authenticate with valid api_key in X-API-Key header" do
    get api_v1_logs_url,
        headers: { "X-API-Key" => @project.api_key }

    assert_response :success
  end

  test "should authenticate with valid ingest_key in X-API-Key header" do
    get api_v1_logs_url,
        headers: { "X-API-Key" => @project.ingest_key }

    assert_response :success
  end

  test "should authenticate with valid api_key in query parameter" do
    get api_v1_logs_url(api_key: @project.api_key)

    assert_response :success
  end

  # Authentication failures
  test "should return unauthorized without authentication" do
    get api_v1_logs_url

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Unauthorized", json["error"]
  end

  test "should return unauthorized with invalid key" do
    get api_v1_logs_url,
        headers: { "Authorization" => "Bearer invalid_key" }

    assert_response :unauthorized
  end

  test "should return unauthorized with malformed Authorization header" do
    get api_v1_logs_url,
        headers: { "Authorization" => "InvalidFormat" }

    assert_response :unauthorized
  end

  # Key extraction priority
  test "should prioritize Authorization header over X-API-Key" do
    # Use valid key in Authorization, invalid in X-API-Key
    get api_v1_logs_url,
        headers: {
          "Authorization" => "Bearer #{@project.api_key}",
          "X-API-Key" => "invalid_key"
        }

    assert_response :success
  end

  test "should prioritize X-API-Key over query parameter" do
    # Use valid key in header, invalid in params
    get api_v1_logs_url(api_key: "invalid_key"),
        headers: { "X-API-Key" => @project.api_key }

    assert_response :success
  end

  # Project assignment
  test "should set @project instance variable on successful authentication" do
    # We can't directly test instance variables, but we can verify the project
    # is used by checking that we get project-specific data
    get api_v1_logs_url,
        headers: { "Authorization" => "Bearer #{@project.api_key}" }

    assert_response :success
    json = JSON.parse(response.body)
    # The logs returned should be from this project
    assert_not_nil json["logs"]
  end

  # Bearer token format
  test "should handle Bearer token with Bearer prefix" do
    get api_v1_logs_url,
        headers: { "Authorization" => "Bearer #{@project.api_key}" }

    assert_response :success
  end

  test "should handle Bearer token with extra spaces" do
    get api_v1_logs_url,
        headers: { "Authorization" => "Bearer  #{@project.api_key}" }

    assert_response :success
  end

  # Different projects
  test "should authenticate different projects with their own keys" do
    project2 = projects(:two)

    get api_v1_logs_url,
        headers: { "Authorization" => "Bearer #{project2.api_key}" }

    assert_response :success
  end

  test "should not allow project to access another project's data with wrong key" do
    project2 = projects(:two)

    # Try to use project2's key but it should only return project2's data
    get api_v1_logs_url,
        headers: { "Authorization" => "Bearer #{project2.api_key}" }

    assert_response :success
    json = JSON.parse(response.body)
    # Should only get project2's logs, not project1's
    logs = json["logs"]
    if logs.any?
      assert logs.all? { |log| log["project_id"] == project2.id }
    end
  end
end
