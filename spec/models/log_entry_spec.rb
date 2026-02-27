require "rails_helper"

RSpec.describe LogEntry, type: :model, timescaledb: true do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "constants" do
    it "defines the correct LEVELS" do
      expect(LogEntry::LEVELS).to eq(%w[debug info warn error fatal])
    end
  end

  describe "validations" do
    subject { build(:log_entry) }

    it { is_expected.to validate_presence_of(:timestamp) }
    it { is_expected.to validate_presence_of(:level) }
    it { is_expected.to validate_inclusion_of(:level).in_array(LogEntry::LEVELS) }

    it "rejects an unknown level" do
      entry = build(:log_entry, level: "trace")
      expect(entry).not_to be_valid
      expect(entry.errors[:level]).to be_present
    end
  end

  describe "default_scope" do
    let(:project) { create(:project) }

    it "orders by timestamp descending" do
      old = create(:log_entry, project: project, timestamp: 2.hours.ago)
      mid = create(:log_entry, project: project, timestamp: 1.hour.ago)
      recent = create(:log_entry, project: project, timestamp: Time.current)

      ordered = project.log_entries.to_a
      expect(ordered.first).to eq(recent)
      expect(ordered.last).to eq(old)
    end
  end

  describe ".counts_by_level" do
    let(:project) { create(:project) }

    it "returns a hash of level → count" do
      create(:log_entry, :error, project: project)
      create(:log_entry, :error, project: project)
      create(:log_entry, :warn, project: project)
      create(:log_entry, :info, project: project)

      counts = project.log_entries.counts_by_level
      expect(counts["error"]).to eq(2)
      expect(counts["warn"]).to eq(1)
      expect(counts["info"]).to eq(1)
    end
  end

  describe ".recent_counts" do
    let(:project) { create(:project) }

    it "counts entries within the given window" do
      create(:log_entry, :error, project: project, timestamp: 30.minutes.ago)
      create(:log_entry, :error, project: project, timestamp: 2.hours.ago)
      create(:log_entry, :warn, project: project, timestamp: 10.minutes.ago)

      counts = project.log_entries.recent_counts(since: 1.hour.ago)
      expect(counts["error"]).to eq(1)
      expect(counts["warn"]).to eq(1)
    end

    it "uses 1.hour.ago as the default window" do
      create(:log_entry, :error, project: project, timestamp: 30.minutes.ago)
      create(:log_entry, :error, project: project, timestamp: 90.minutes.ago)

      counts = project.log_entries.recent_counts
      expect(counts["error"]).to eq(1)
    end
  end

  describe "#composite_key" do
    it "returns id_timestamp in ISO 8601 with microseconds" do
      ts = Time.zone.parse("2025-06-15T10:30:00.123456+00:00")
      entry = build(:log_entry, timestamp: ts)
      entry.id = "abc-123"

      key = entry.composite_key
      expect(key).to start_with("abc-123_")
      expect(key).to include("2025-06-15")
    end

    it "generates a parseable composite key" do
      entry = create(:log_entry)
      key = entry.composite_key
      # Should match the pattern id_YYYY-MM-DD...
      expect(key).to match(/\A.+_\d{4}-\d{2}-\d{2}/)
    end
  end
end
