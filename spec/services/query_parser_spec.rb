require "rails_helper"

RSpec.describe QueryParser, type: :service, timescaledb: true do
  let(:project) { create(:project) }

  def parse_and_apply(query)
    QueryParser.new(query).parse.apply(project.log_entries)
  end

  describe "#parse" do
    it "returns self for chaining" do
      parser = QueryParser.new("level:error")
      expect(parser.parse).to be(parser)
    end
  end

  describe "level filter" do
    let!(:error_entry) { create(:log_entry, :error, project: project) }
    let!(:warn_entry)  { create(:log_entry, :warn, project: project) }
    let!(:info_entry)  { create(:log_entry, :info, project: project) }

    it "filters by a single level" do
      results = parse_and_apply("level:error")
      expect(results).to include(error_entry)
      expect(results).not_to include(warn_entry, info_entry)
    end

    it "filters with negation (level:!debug)" do
      debug_entry = create(:log_entry, :debug, project: project)
      results = parse_and_apply("level:!debug")
      expect(results).not_to include(debug_entry)
      expect(results).to include(error_entry, warn_entry)
    end

    it "filters by comma-separated levels" do
      results = parse_and_apply("level:error,warn")
      expect(results).to include(error_entry, warn_entry)
      expect(results).not_to include(info_entry)
    end

    it "ignores unknown levels in list" do
      results = parse_and_apply("level:error,trace")
      expect(results).to include(error_entry)
    end
  end

  describe "environment filter" do
    let!(:prod_entry) { create(:log_entry, project: project, environment: "production") }
    let!(:stg_entry)  { create(:log_entry, project: project, environment: "staging") }

    it "filters by env: alias" do
      results = parse_and_apply("env:production")
      expect(results).to include(prod_entry)
      expect(results).not_to include(stg_entry)
    end

    it "filters by environment: key" do
      results = parse_and_apply("environment:staging")
      expect(results).to include(stg_entry)
      expect(results).not_to include(prod_entry)
    end

    it "supports negation" do
      results = parse_and_apply("env:!production")
      expect(results).not_to include(prod_entry)
      expect(results).to include(stg_entry)
    end
  end

  describe "service filter" do
    let!(:web_entry)    { create(:log_entry, project: project, service: "web") }
    let!(:worker_entry) { create(:log_entry, project: project, service: "worker") }

    it "filters by service" do
      results = parse_and_apply("service:web")
      expect(results).to include(web_entry)
      expect(results).not_to include(worker_entry)
    end
  end

  describe "commit and branch filters" do
    let!(:main_entry)   { create(:log_entry, project: project, branch: "main",    commit: "abc123") }
    let!(:deploy_entry) { create(:log_entry, project: project, branch: "release", commit: "def456") }

    it "filters by commit" do
      results = parse_and_apply("commit:abc123")
      expect(results).to include(main_entry)
      expect(results).not_to include(deploy_entry)
    end

    it "filters by branch" do
      results = parse_and_apply("branch:main")
      expect(results).to include(main_entry)
      expect(results).not_to include(deploy_entry)
    end
  end

  describe "request_id and session_id filters" do
    let!(:req_entry)  { create(:log_entry, :with_request, project: project) }
    let!(:sess_entry) { create(:log_entry, :with_session, project: project) }

    it "filters by request_id alias 'request'" do
      results = parse_and_apply("request:#{req_entry.request_id}")
      expect(results).to include(req_entry)
    end

    it "filters by session alias 'session'" do
      results = parse_and_apply("session:#{sess_entry.session_id}")
      expect(results).to include(sess_entry)
    end
  end

  describe "time filters" do
    let!(:recent_entry) { create(:log_entry, project: project, timestamp: 30.minutes.ago) }
    let!(:old_entry)    { create(:log_entry, project: project, timestamp: 5.hours.ago) }

    it "filters with since:1h" do
      results = parse_and_apply("since:1h")
      expect(results).to include(recent_entry)
      expect(results).not_to include(old_entry)
    end

    it "supports since with days (since:1d)" do
      day_old = create(:log_entry, project: project, timestamp: 2.days.ago)
      results = parse_and_apply("since:1d")
      expect(results).to include(recent_entry, old_entry)
      expect(results).not_to include(day_old)
    end
  end

  describe "JSONB data filters" do
    let!(:user_entry) do
      create(:log_entry, project: project, data: { "user_id" => "42" })
    end
    let!(:other_entry) do
      create(:log_entry, project: project, data: { "user_id" => "99" })
    end

    it "filters by exact JSONB field value" do
      results = parse_and_apply("data.user_id:42")
      expect(results).to include(user_entry)
      expect(results).not_to include(other_entry)
    end
  end

  describe "text search" do
    let!(:payment_entry) { create(:log_entry, project: project, message: "Payment failed for user") }
    let!(:login_entry)   { create(:log_entry, project: project, message: "User logged in") }

    it "searches message with quoted text" do
      results = parse_and_apply('"Payment failed"')
      expect(results).to include(payment_entry)
      expect(results).not_to include(login_entry)
    end
  end

  describe "OR groups" do
    let!(:error_entry) { create(:log_entry, :error, project: project) }
    let!(:warn_entry)  { create(:log_entry, :warn,  project: project) }
    let!(:info_entry)  { create(:log_entry, :info,  project: project) }

    it "combines filters with OR" do
      results = parse_and_apply("level:error OR level:warn")
      expect(results).to include(error_entry, warn_entry)
      expect(results).not_to include(info_entry)
    end
  end

  describe "| stats command" do
    let!(:e1) { create(:log_entry, :error, project: project) }
    let!(:e2) { create(:log_entry, :error, project: project) }
    let!(:w1) { create(:log_entry, :warn,  project: project) }

    it "detects stats command via stats?" do
      parser = QueryParser.new("since:1h | stats by:level").parse
      expect(parser.stats?).to be true
    end

    it "returns false for stats? when no stats command" do
      parser = QueryParser.new("level:error").parse
      expect(parser.stats?).to be false
    end

    it "groups by level" do
      parser = QueryParser.new("| stats by:level").parse
      result = parser.apply_stats(project.log_entries)
      expect(result["error"]).to eq(2)
      expect(result["warn"]).to eq(1)
    end

    it "groups by environment" do
      parser = QueryParser.new("| stats by:environment").parse
      result = parser.apply_stats(project.log_entries)
      expect(result).to be_a(Hash)
    end

    it "returns default stats when group_by unknown" do
      parser = QueryParser.new("| stats").parse
      result = parser.apply_stats(project.log_entries)
      expect(result).to have_key(:total)
      expect(result).to have_key(:by_level)
    end
  end

  describe "#limit" do
    it "defaults to 25 with no command" do
      parser = QueryParser.new("level:error").parse
      expect(parser.limit).to eq(25)
    end

    it "returns the limit from | first N" do
      parser = QueryParser.new("level:error | first 50").parse
      expect(parser.limit).to eq(50)
    end

    it "returns the limit from | last N" do
      parser = QueryParser.new("| last 100").parse
      expect(parser.limit).to eq(100)
    end
  end

  describe "ordering" do
    let!(:older)  { create(:log_entry, project: project, timestamp: 2.hours.ago) }
    let!(:newer)  { create(:log_entry, project: project, timestamp: 1.hour.ago) }

    it "orders by timestamp descending by default" do
      results = parse_and_apply("level:info,warn,error,debug,fatal")
      expect(results.first.timestamp).to be >= results.last.timestamp
    end

    it "orders ascending with | first command" do
      results = parse_and_apply("| first 10")
      expect(results.to_a.first.timestamp).to be <= results.to_a.last.timestamp
    end
  end

  describe "empty query" do
    it "returns all entries for the scope" do
      create_list(:log_entry, 3, project: project)
      other_project = create(:project)
      create(:log_entry, project: other_project)

      results = parse_and_apply("")
      expect(results.count).to eq(3)
    end
  end
end
