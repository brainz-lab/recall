require "test_helper"

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    ENV["RECALL_MASTER_KEY"] = "test_master_key_12345"
    @headers = { "X-Master-Key" => "test_master_key_12345" }
    @project = projects(:one)
  end

  def teardown
    ENV.delete("RECALL_MASTER_KEY")
  end

  # Authentication tests
  test "should require master key authentication" do
    post provision_api_v1_projects_url, params: { name: "Test Project" }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Unauthorized", json["error"]
  end

  test "should reject invalid master key" do
    post provision_api_v1_projects_url,
         params: { name: "Test Project" },
         headers: { "X-Master-Key" => "wrong_key" }

    assert_response :unauthorized
  end

  test "should authenticate with valid master key" do
    post provision_api_v1_projects_url,
         params: { name: "New API Project" },
         headers: @headers

    assert_response :success
  end

  test "should reject when master key env is not set" do
    ENV.delete("RECALL_MASTER_KEY")

    post provision_api_v1_projects_url,
         params: { name: "Test Project" },
         headers: @headers

    assert_response :unauthorized
  end

  # Provision action
  test "should create new project on provision" do
    assert_difference("Project.count") do
      post provision_api_v1_projects_url,
           params: { name: "Brand New Project" },
           headers: @headers
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Brand New Project", json["name"]
    assert json["slug"].present?
    assert json["ingest_key"].present?
    assert json["api_key"].present?
  end

  test "should return existing project on provision with same name" do
    existing_project = projects(:one)

    assert_no_difference("Project.count") do
      post provision_api_v1_projects_url,
           params: { name: existing_project.name },
           headers: @headers
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal existing_project.name, json["name"]
    assert_equal existing_project.slug, json["slug"]
    assert_equal existing_project.ingest_key, json["ingest_key"]
    assert_equal existing_project.api_key, json["api_key"]
  end

  test "provision should return keys" do
    post provision_api_v1_projects_url,
         params: { name: "Keys Test Project" },
         headers: @headers

    json = JSON.parse(response.body)
    assert json["ingest_key"].start_with?("rcl_ingest_")
    assert json["api_key"].start_with?("rcl_api_")
  end

  # Lookup action
  test "should lookup project by name" do
    get lookup_api_v1_projects_url(name: @project.name), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @project.name, json["name"]
    assert_equal @project.slug, json["slug"]
  end

  test "should lookup project by slug" do
    get lookup_api_v1_projects_url(name: @project.slug), headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @project.name, json["name"]
  end

  test "should return 404 for unknown project" do
    get lookup_api_v1_projects_url(name: "nonexistent_project"), headers: @headers

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Project not found", json["error"]
  end

  test "lookup should require authentication" do
    get lookup_api_v1_projects_url(name: @project.name)

    assert_response :unauthorized
  end

  test "lookup should return all project keys" do
    get lookup_api_v1_projects_url(name: @project.name), headers: @headers

    json = JSON.parse(response.body)
    assert json.key?("name")
    assert json.key?("slug")
    assert json.key?("ingest_key")
    assert json.key?("api_key")
  end
end
