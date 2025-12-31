require "test_helper"

class DashboardHelperTest < ActionView::TestCase
  include DashboardHelper

  # Icon tests
  test "icon returns svg for logs" do
    result = icon(:logs)
    assert result.present?
    assert result.include?("<svg")
  end

  test "icon returns svg for analytics" do
    result = icon(:analytics)
    assert result.present?
    assert result.include?("<svg")
  end

  test "icon returns svg for setup" do
    result = icon(:setup)
    assert result.present?
    assert result.include?("<svg")
  end

  test "icon returns svg for mcp" do
    result = icon(:mcp)
    assert result.present?
    assert result.include?("<svg")
  end

  test "icon returns svg for settings" do
    result = icon(:settings)
    assert result.present?
    assert result.include?("<svg")
  end

  test "icon returns svg for dev_tools" do
    result = icon(:dev_tools)
    assert result.present?
    assert result.include?("<svg")
  end

  test "icon returns nil for unknown icon" do
    result = icon(:unknown_icon)
    assert_nil result
  end

  test "icon accepts string name" do
    result = icon("logs")
    assert result.present?
    assert result.include?("<svg")
  end

  test "icon returns html_safe string" do
    result = icon(:logs)
    assert result.html_safe?
  end

  # nav_active? tests
  test "nav_active? returns true for logs when controller is logs" do
    self.stubs(:controller_name).returns("logs")
    assert nav_active?("/logs")
  end

  test "nav_active? returns false for logs when controller is not logs" do
    self.stubs(:controller_name).returns("projects")
    assert_not nav_active?("/logs")
  end

  test "nav_active? returns true for analytics when action is analytics" do
    self.stubs(:action_name).returns("analytics")
    assert nav_active?("/analytics")
  end

  test "nav_active? returns true for setup when action is setup" do
    self.stubs(:action_name).returns("setup")
    assert nav_active?("/setup")
  end

  test "nav_active? returns true for mcp when action is mcp_setup" do
    self.stubs(:action_name).returns("mcp_setup")
    assert nav_active?("/mcp")
  end

  test "nav_active? returns true for settings when action is edit" do
    self.stubs(:action_name).returns("edit")
    assert nav_active?("/settings")
  end

  test "nav_active? uses path includes for other patterns" do
    mock_request = mock
    mock_request.stubs(:path).returns("/custom/path")
    self.stubs(:request).returns(mock_request)

    assert nav_active?("/custom")
    assert_not nav_active?("/other")
  end

  # nav_link_class tests
  test "nav_link_class returns active class when active" do
    self.stubs(:controller_name).returns("logs")
    result = nav_link_class("/logs")
    assert_equal "nav-item active", result
  end

  test "nav_link_class returns inactive class when not active" do
    self.stubs(:controller_name).returns("projects")
    result = nav_link_class("/logs")
    assert_equal "nav-item", result
  end
end
