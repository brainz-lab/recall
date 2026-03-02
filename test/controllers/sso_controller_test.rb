require "test_helper"

class SsoControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Set up environment for tests
    ENV["BRAINZLAB_PLATFORM_URL"] = "http://platform:3000"
    ENV["BRAINZLAB_PLATFORM_EXTERNAL_URL"] = "http://platform.localhost"
    ENV["SERVICE_KEY"] = "test_service_key"
  end

  def teardown
    ENV.delete("BRAINZLAB_PLATFORM_URL")
    ENV.delete("BRAINZLAB_PLATFORM_EXTERNAL_URL")
    ENV.delete("SERVICE_KEY")
  end

  # Callback action - no token
  test "should redirect to platform when no token provided" do
    get sso_callback_url

    assert_redirected_to "http://platform.localhost"
  end

  test "should redirect to platform when token is blank" do
    get sso_callback_url(token: "")

    assert_redirected_to "http://platform.localhost"
  end

  # Callback action - with valid token
  test "should set session on valid token" do
    # Stub the HTTP request
    stub_valid_sso_response

    get sso_callback_url(token: "valid_token")

    assert_redirected_to dashboard_root_path
    assert session[:platform_user_id].present?
  end

  test "should use return_to parameter when provided" do
    stub_valid_sso_response

    get sso_callback_url(token: "valid_token", return_to: "/custom/path")

    assert_redirected_to "/custom/path"
  end

  test "should store user info in session" do
    stub_valid_sso_response

    get sso_callback_url(token: "valid_token")

    assert_equal "user123", session[:platform_user_id]
    assert_equal "project456", session[:platform_project_id]
    assert_equal "org789", session[:platform_organization_id]
    assert_equal "test-project", session[:project_slug]
    assert_equal "test@example.com", session[:user_email]
    assert_equal "Test User", session[:user_name]
  end

  # Callback action - with invalid token
  test "should redirect to platform with error on invalid token" do
    stub_invalid_sso_response

    get sso_callback_url(token: "invalid_token")

    assert_redirected_to "http://platform.localhost/login?error=sso_failed"
  end

  # Callback action - platform error
  test "should handle platform connection error gracefully" do
    stub_sso_connection_error

    get sso_callback_url(token: "any_token")

    assert_redirected_to "http://platform.localhost/login?error=sso_failed"
  end

  private

  def stub_valid_sso_response
    mock_response = Minitest::Mock.new
    mock_response.expect :code, "200"
    mock_response.expect :body, {
      user_id: "user123",
      project_id: "project456",
      organization_id: "org789",
      project_slug: "test-project",
      user_email: "test@example.com",
      user_name: "Test User"
    }.to_json

    Net::HTTP.stub :new, ->(*) {
      mock_http = Minitest::Mock.new
      mock_http.expect :use_ssl=, nil, [ false ]
      mock_http.expect :request, mock_response, [ Net::HTTP::Post ]
      mock_http
    } do
      yield if block_given?
    end
  end

  def stub_invalid_sso_response
    mock_response = Minitest::Mock.new
    mock_response.expect :code, "401"

    Net::HTTP.stub :new, ->(*) {
      mock_http = Minitest::Mock.new
      mock_http.expect :use_ssl=, nil, [ false ]
      mock_http.expect :request, mock_response, [ Net::HTTP::Post ]
      mock_http
    } do
      yield if block_given?
    end
  end

  def stub_sso_connection_error
    Net::HTTP.stub :new, ->(*) {
      raise StandardError, "Connection failed"
    } do
      yield if block_given?
    end
  end
end
