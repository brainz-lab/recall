require "test_helper"

class LogExporterTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @exporter = LogExporter.new(@project)
  end

  # Initialization
  test "should initialize with project" do
    assert_equal @project, @exporter.instance_variable_get(:@project)
  end

  test "should initialize with default format json" do
    exporter = LogExporter.new(@project)
    assert_equal :json, exporter.instance_variable_get(:@format)
  end

  test "should initialize with csv format" do
    exporter = LogExporter.new(@project, format: :csv)
    assert_equal :csv, exporter.instance_variable_get(:@format)
  end

  test "should initialize with query" do
    exporter = LogExporter.new(@project, query: "level:error")
    assert_equal "level:error", exporter.instance_variable_get(:@query)
  end

  test "should initialize with since parameter" do
    exporter = LogExporter.new(@project, since: "1h")
    assert_equal "1h", exporter.instance_variable_get(:@since)
  end

  test "should initialize with until parameter" do
    exporter = LogExporter.new(@project, until_time: "2h")
    assert_equal "2h", exporter.instance_variable_get(:@until_time)
  end

  # Export functionality
  test "should export to json by default" do
    exporter = LogExporter.new(@project)
    result = exporter.export
    assert_not_nil result
    parsed = JSON.parse(result)
    assert_kind_of Array, parsed
  end

  test "should export to csv when format is csv" do
    exporter = LogExporter.new(@project, format: :csv)
    result = exporter.export
    assert_not_nil result
    assert_includes result, "id,timestamp,level,message"
  end

  # JSON export
  test "to_json should return valid json" do
    result = @exporter.to_json
    assert_nothing_raised do
      JSON.parse(result)
    end
  end

  test "to_json should include log entries" do
    result = @exporter.to_json
    logs = JSON.parse(result)
    assert logs.size > 0
  end

  # CSV export
  test "to_csv should return csv string" do
    exporter = LogExporter.new(@project, format: :csv)
    result = exporter.to_csv
    assert_kind_of String, result
  end

  test "to_csv should include headers" do
    exporter = LogExporter.new(@project, format: :csv)
    result = exporter.to_csv
    headers = result.lines.first.strip
    assert_includes headers, "id"
    assert_includes headers, "timestamp"
    assert_includes headers, "level"
    assert_includes headers, "message"
  end

  test "to_csv should include all export columns" do
    exporter = LogExporter.new(@project, format: :csv)
    result = exporter.to_csv
    headers = result.lines.first.strip.split(",")

    LogExporter::EXPORT_COLUMNS.each do |column|
      assert_includes headers, column
    end
  end

  # Filename generation
  test "filename should include project name" do
    filename = @exporter.filename
    assert_includes filename, @project.name.parameterize
  end

  test "filename should include timestamp" do
    filename = @exporter.filename
    assert_match /\d{8}_\d{6}/, filename
  end

  test "filename should have json extension by default" do
    filename = @exporter.filename
    assert_match /\.json$/, filename
  end

  test "filename should have csv extension for csv format" do
    exporter = LogExporter.new(@project, format: :csv)
    filename = exporter.filename
    assert_match /\.csv$/, filename
  end

  test "filename should sanitize project name" do
    project = Project.create!(name: "Test Project With Spaces!")
    exporter = LogExporter.new(project)
    filename = exporter.filename
    assert_includes filename, "test-project-with-spaces"
  end

  # Content type
  test "content_type should return json for json format" do
    exporter = LogExporter.new(@project, format: :json)
    assert_equal "application/json", exporter.content_type
  end

  test "content_type should return csv for csv format" do
    exporter = LogExporter.new(@project, format: :csv)
    assert_equal "text/csv", exporter.content_type
  end

  # Count
  test "count should return number of logs" do
    count = @exporter.count
    assert count > 0
    assert_equal @project.log_entries.count, count
  end

  # Filtering
  test "should filter by query" do
    exporter = LogExporter.new(@project, query: "level:error")
    count = exporter.count
    assert_equal @project.log_entries.where(level: "error").count, count
  end

  test "should filter by since parameter" do
    exporter = LogExporter.new(@project, since: "1h")
    count = exporter.count
    expected = @project.log_entries.where("timestamp >= ?", 1.hour.ago).count
    assert_equal expected, count
  end

  test "should filter by until parameter" do
    exporter = LogExporter.new(@project, until_time: "1h")
    count = exporter.count
    expected = @project.log_entries.where("timestamp <= ?", 1.hour.ago).count
    assert_equal expected, count
  end

  test "should combine query and time filters" do
    exporter = LogExporter.new(
      @project,
      query: "level:info",
      since: "2h"
    )
    count = exporter.count
    expected = @project.log_entries
                       .where(level: "info")
                       .where("timestamp >= ?", 2.hours.ago)
                       .count
    assert_equal expected, count
  end

  # Time parsing
  test "should parse relative time with minutes" do
    exporter = LogExporter.new(@project, since: "30m")
    # Should not raise error
    assert_nothing_raised do
      exporter.count
    end
  end

  test "should parse relative time with hours" do
    exporter = LogExporter.new(@project, since: "2h")
    assert_nothing_raised do
      exporter.count
    end
  end

  test "should parse relative time with days" do
    exporter = LogExporter.new(@project, since: "7d")
    assert_nothing_raised do
      exporter.count
    end
  end

  test "should parse relative time with weeks" do
    exporter = LogExporter.new(@project, since: "2w")
    assert_nothing_raised do
      exporter.count
    end
  end

  test "should handle invalid time gracefully" do
    exporter = LogExporter.new(@project, since: "invalid")
    # Should not raise error, should return some result
    assert_nothing_raised do
      exporter.count
    end
  end

  # Data completeness
  test "exported json should include all log fields" do
    exporter = LogExporter.new(@project)
    result = exporter.to_json
    logs = JSON.parse(result)

    if logs.any?
      first_log = logs.first
      assert first_log.key?("id")
      assert first_log.key?("timestamp")
      assert first_log.key?("level")
    end
  end

  test "exported csv should include data field as json" do
    # Create a log with data
    @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      data: { key: "value" }
    )

    exporter = LogExporter.new(@project, format: :csv)
    result = exporter.to_csv

    # CSV should contain JSON representation of data
    assert_includes result, "key"
  end
end
