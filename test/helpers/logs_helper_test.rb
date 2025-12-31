require "test_helper"

class LogsHelperTest < ActionView::TestCase
  include LogsHelper

  def setup
    @log = log_entries(:one)
  end

  # interactive_json tests
  test "interactive_json returns empty string for blank data" do
    result = interactive_json(nil)
    assert_equal "", result
  end

  test "interactive_json returns empty string for empty hash" do
    result = interactive_json({})
    assert_equal "", result
  end

  test "interactive_json returns div with data attributes" do
    data = { user_id: 123, action: "login" }
    result = interactive_json(data)

    assert result.include?("interactive-json")
    assert result.include?("data-controller=\"json-tree\"")
    assert result.include?("data-json-tree-data-value")
  end

  test "interactive_json uses default prefix" do
    data = { key: "value" }
    result = interactive_json(data)

    assert result.include?("data-json-tree-prefix-value=\"data\"")
  end

  test "interactive_json uses custom prefix" do
    data = { key: "value" }
    result = interactive_json(data, "custom")

    assert result.include?("data-json-tree-prefix-value=\"custom\"")
  end

  test "interactive_json serializes data to json" do
    data = { user_id: 123, nested: { key: "value" } }
    result = interactive_json(data)

    assert result.include?("user_id")
    assert result.include?("123")
  end

  # log_cache_key tests
  test "log_cache_key generates consistent key" do
    key1 = log_cache_key(@log)
    key2 = log_cache_key(@log)

    assert_equal key1, key2
  end

  test "log_cache_key includes log id" do
    key = log_cache_key(@log)
    assert key.include?(@log.id.to_s)
  end

  test "log_cache_key includes timestamp" do
    key = log_cache_key(@log)
    assert key.include?(@log.timestamp.to_i.to_s)
  end

  test "log_cache_key includes version" do
    key = log_cache_key(@log)
    assert key.start_with?("log_row/v3/")
  end

  # log_filter_button tests
  test "log_filter_button returns nil for blank value" do
    result = log_filter_button(label: "Level", value: nil, query_prefix: "level")
    assert_nil result
  end

  test "log_filter_button returns nil for empty value" do
    result = log_filter_button(label: "Level", value: "", query_prefix: "level")
    assert_nil result
  end

  test "log_filter_button returns button element" do
    result = log_filter_button(label: "Level", value: "error", query_prefix: "level")

    assert result.include?("<button")
    assert result.include?("Level: error")
  end

  test "log_filter_button includes data action" do
    result = log_filter_button(label: "Level", value: "error", query_prefix: "level")

    assert result.include?("data-action=\"click->query#filter\"")
    assert result.include?("data-query=\"level:error\"")
  end

  test "log_filter_button includes hover class" do
    result = log_filter_button(label: "Level", value: "error", query_prefix: "level")

    assert result.include?("hover:underline")
  end

  test "log_filter_button uses default title" do
    result = log_filter_button(label: "Level", value: "error", query_prefix: "level")

    assert result.include?("Filter by this level")
  end

  test "log_filter_button uses custom title" do
    result = log_filter_button(
      label: "Level",
      value: "error",
      query_prefix: "level",
      title: "Custom title"
    )

    assert result.include?("title=\"Custom title\"")
  end

  # log_icon tests
  test "log_icon returns session icon" do
    result = log_icon(:session)

    assert result.present?
    assert result.include?("<svg")
  end

  test "log_icon returns request icon" do
    result = log_icon(:request)

    assert result.present?
    assert result.include?("<svg")
  end

  test "log_icon returns nil for unknown icon" do
    result = log_icon(:unknown)
    assert_nil result
  end

  test "log_icon returns html_safe string" do
    result = log_icon(:session)
    assert result.html_safe?
  end
end
