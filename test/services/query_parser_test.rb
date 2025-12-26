require "test_helper"

class QueryParserTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
  end

  # Parsing tests
  test "should parse empty query" do
    parser = QueryParser.new("").parse
    assert_not_nil parser
  end

  test "should parse level filter" do
    parser = QueryParser.new("level:error").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["error"], scope.pluck(:level).uniq
  end

  test "should parse multiple levels" do
    parser = QueryParser.new("level:error,warn").parse
    scope = parser.apply(@project.log_entries)
    levels = scope.pluck(:level).uniq.sort
    assert levels.all? { |l| ["error", "warn"].include?(l) }
  end

  test "should parse negated level filter" do
    parser = QueryParser.new("level:!debug").parse
    scope = parser.apply(@project.log_entries)
    assert_not_includes scope.pluck(:level), "debug"
  end

  test "should parse environment filter" do
    parser = QueryParser.new("env:production").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["production"], scope.pluck(:environment).uniq
  end

  test "should accept environment as full word" do
    parser = QueryParser.new("environment:staging").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["staging"], scope.pluck(:environment).uniq
  end

  test "should parse commit filter" do
    parser = QueryParser.new("commit:abc123").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["abc123"], scope.pluck(:commit).uniq
  end

  test "should parse branch filter" do
    parser = QueryParser.new("branch:main").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["main"], scope.pluck(:branch).uniq
  end

  test "should parse service filter" do
    parser = QueryParser.new("service:web").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["web"], scope.pluck(:service).uniq
  end

  test "should parse host filter" do
    parser = QueryParser.new("host:server-1").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["server-1"], scope.pluck(:host).uniq
  end

  test "should parse request_id filter" do
    parser = QueryParser.new("request_id:req_test_1").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["req_test_1"], scope.pluck(:request_id).uniq
  end

  test "should accept request as alias for request_id" do
    parser = QueryParser.new("request:req_test_1").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["req_test_1"], scope.pluck(:request_id).uniq
  end

  test "should parse session_id filter" do
    parser = QueryParser.new("session_id:sess_test_session_1").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["sess_test_session_1"], scope.pluck(:session_id).uniq
  end

  test "should accept session as alias for session_id" do
    parser = QueryParser.new("session:sess_test_session_1").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["sess_test_session_1"], scope.pluck(:session_id).uniq
  end

  # Time filters
  test "should parse since filter with minutes" do
    parser = QueryParser.new("since:30m").parse
    scope = parser.apply(@project.log_entries)
    assert scope.all? { |entry| entry.timestamp > 30.minutes.ago }
  end

  test "should parse since filter with hours" do
    parser = QueryParser.new("since:2h").parse
    scope = parser.apply(@project.log_entries)
    assert scope.all? { |entry| entry.timestamp > 2.hours.ago }
  end

  test "should parse since filter with days" do
    parser = QueryParser.new("since:7d").parse
    scope = parser.apply(@project.log_entries)
    assert scope.count > 0
  end

  test "should parse until filter" do
    parser = QueryParser.new("until:1h").parse
    scope = parser.apply(@project.log_entries)
    assert scope.all? { |entry| entry.timestamp < 1.hour.ago }
  end

  # JSONB data filters
  test "should parse data field exact match" do
    # Create entry with specific data
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      data: { user_id: "123" }
    )

    parser = QueryParser.new("data.user_id:123").parse
    scope = parser.apply(@project.log_entries)
    assert_includes scope.pluck(:id), entry.id
  end

  test "should parse nested data fields" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      data: { user: { id: "456" } }
    )

    parser = QueryParser.new("data.user.id:456").parse
    scope = parser.apply(@project.log_entries)
    assert_includes scope.pluck(:id), entry.id
  end

  test "should parse data field with wildcard" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      data: { action: "user:login" }
    )

    parser = QueryParser.new("data.action:user:*").parse
    scope = parser.apply(@project.log_entries)
    assert_includes scope.pluck(:id), entry.id
  end

  test "should parse data field with numeric comparison" do
    entry = @project.log_entries.create!(
      timestamp: Time.current,
      level: "info",
      message: "Test",
      data: { count: 50 }
    )

    parser = QueryParser.new("data.count:>10").parse
    scope = parser.apply(@project.log_entries)
    assert_includes scope.pluck(:id), entry.id
  end

  # Text search
  test "should parse quoted text search" do
    parser = QueryParser.new('"Test error"').parse
    scope = parser.apply(@project.log_entries)
    # Should search in message field
    assert_not_nil scope
  end

  test "should parse multiple filters combined" do
    parser = QueryParser.new("level:error env:production since:1h").parse
    scope = parser.apply(@project.log_entries)
    assert_not_nil scope
  end

  test "should parse text search with filters" do
    parser = QueryParser.new('"error message" level:error').parse
    scope = parser.apply(@project.log_entries)
    assert_not_nil scope
  end

  # Commands
  test "should detect stats command" do
    parser = QueryParser.new("level:error | stats").parse
    assert parser.stats?
  end

  test "should parse stats by level" do
    parser = QueryParser.new("| stats by:level").parse
    stats = parser.apply_stats(@project.log_entries)
    assert_kind_of Hash, stats
  end

  test "should parse stats by commit" do
    parser = QueryParser.new("| stats by:commit").parse
    stats = parser.apply_stats(@project.log_entries)
    assert_kind_of Hash, stats
  end

  test "should parse stats by environment" do
    parser = QueryParser.new("| stats by:env").parse
    stats = parser.apply_stats(@project.log_entries)
    assert_kind_of Hash, stats
  end

  test "should parse stats by hour" do
    parser = QueryParser.new("| stats by:hour").parse
    stats = parser.apply_stats(@project.log_entries)
    assert_kind_of Hash, stats
  end

  test "should parse stats by day" do
    parser = QueryParser.new("| stats by:day").parse
    stats = parser.apply_stats(@project.log_entries)
    assert_kind_of Hash, stats
  end

  test "should parse stats without grouping" do
    parser = QueryParser.new("| stats").parse
    stats = parser.apply_stats(@project.log_entries)
    assert stats.key?(:total)
    assert stats.key?(:by_level)
  end

  test "should parse first command" do
    parser = QueryParser.new("| first 10").parse
    assert_equal 10, parser.limit
  end

  test "should use default limit of 100 for first command" do
    parser = QueryParser.new("| first").parse
    assert_equal 100, parser.limit
  end

  test "should parse last command" do
    parser = QueryParser.new("| last 50").parse
    assert_equal 50, parser.limit
  end

  test "should order by timestamp asc for first command" do
    parser = QueryParser.new("| first").parse
    scope = parser.apply(@project.log_entries)
    # Verify ordering (first should be oldest)
    timestamps = scope.limit(2).pluck(:timestamp)
    assert_equal timestamps, timestamps.sort if timestamps.size > 1
  end

  test "should order by timestamp desc by default" do
    parser = QueryParser.new("").parse
    scope = parser.apply(@project.log_entries)
    # Verify ordering (default should be newest first)
    timestamps = scope.limit(2).pluck(:timestamp)
    assert_equal timestamps, timestamps.sort.reverse if timestamps.size > 1
  end

  # OR operator
  test "should parse OR operator" do
    parser = QueryParser.new("level:error OR level:fatal").parse
    scope = parser.apply(@project.log_entries)
    levels = scope.pluck(:level).uniq
    assert levels.all? { |l| ["error", "fatal"].include?(l) }
  end

  test "should parse OR with different fields" do
    parser = QueryParser.new("env:production OR env:staging").parse
    scope = parser.apply(@project.log_entries)
    envs = scope.pluck(:environment).compact.uniq
    assert envs.all? { |e| ["production", "staging"].include?(e) }
  end

  # Edge cases
  test "should handle quoted values in filters" do
    parser = QueryParser.new('message:"error message"').parse
    assert_not_nil parser
  end

  test "should handle filters with dashes" do
    parser = QueryParser.new("host:server-1").parse
    scope = parser.apply(@project.log_entries)
    assert_equal ["server-1"], scope.pluck(:host).uniq
  end

  test "should handle filters with underscores" do
    parser = QueryParser.new("session_id:test_session").parse
    assert_not_nil parser
  end

  test "should ignore invalid levels" do
    parser = QueryParser.new("level:invalid,error").parse
    scope = parser.apply(@project.log_entries)
    # Should only include valid level (error)
    assert_equal ["error"], scope.pluck(:level).uniq
  end
end
