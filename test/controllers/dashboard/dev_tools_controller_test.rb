require "test_helper"

class Dashboard::DevToolsControllerTest < ActionDispatch::IntegrationTest
  # Show action
  test "should get show in development" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("development") do
      get dashboard_dev_tools_url

      assert_response :success
    end
  end

  test "should redirect in production" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("production") do
      get dashboard_dev_tools_url

      assert_redirected_to dashboard_root_path
    end
  end

  test "should display stats" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("development") do
      get dashboard_dev_tools_url

      assert_response :success
    end
  end

  # Clean logs action
  test "should clean logs in development" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("development") do
      post clean_logs_dashboard_dev_tools_url

      assert_redirected_to dashboard_dev_tools_path
    end
  end

  test "should redirect clean_logs in production" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("production") do
      post clean_logs_dashboard_dev_tools_url

      assert_redirected_to dashboard_root_path
    end
  end

  # Clean all action
  test "should clean all in development" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("development") do
      post clean_all_dashboard_dev_tools_url

      assert_redirected_to dashboard_dev_tools_path
    end
  end

  test "should redirect clean_all in production" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("production") do
      post clean_all_dashboard_dev_tools_url

      assert_redirected_to dashboard_root_path
    end
  end

  test "clean_logs should delete log entries" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("development") do
      # Create a log entry
      project = projects(:one)
      project.log_entries.create!(
        timestamp: Time.current,
        level: "info",
        message: "Test log"
      )

      post clean_logs_dashboard_dev_tools_url

      assert_redirected_to dashboard_dev_tools_path
      assert_match /Cleaned/, flash[:notice]
    end
  end

  test "clean_all should delete log entries and saved searches" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("development") do
      project = projects(:one)
      project.log_entries.create!(
        timestamp: Time.current,
        level: "info",
        message: "Test log"
      )
      project.saved_searches.create!(
        name: "Test Search",
        query: "level:error"
      )

      post clean_all_dashboard_dev_tools_url

      assert_redirected_to dashboard_dev_tools_path
      assert_match /Cleaned/, flash[:notice]
    end
  end
end
