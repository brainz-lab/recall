require "rails_helper"

RSpec.describe HypertableFindable, type: :model, timescaledb: true do
  # LogEntry is the only model that includes HypertableFindable
  subject(:entry) { create(:log_entry) }

  describe ".find_by_composite_key" do
    it "finds a record by its composite key" do
      key = entry.composite_key
      found = LogEntry.find_by_composite_key(key)
      expect(found.id).to eq(entry.id)
    end

    it "raises RecordNotFound for an invalid key format" do
      expect {
        LogEntry.find_by_composite_key("not-a-valid-key")
      }.to raise_error(ActiveRecord::RecordNotFound, /Invalid composite key format/)
    end

    it "raises RecordNotFound when the record does not exist" do
      fake_key = "00000000-0000-0000-0000-000000000000_2025-01-01T00:00:00.000000+00:00"
      expect {
        LogEntry.find_by_composite_key(fake_key)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#composite_key" do
    it "encodes id and timestamp into a parseable key" do
      key = entry.composite_key
      # Must match the regex the parser uses: id_YYYY-MM-DD...
      expect(key).to match(/\A.+_\d{4}-\d{2}-\d{2}/)
    end

    it "produces a round-trippable key" do
      key = entry.composite_key
      found = LogEntry.find_by_composite_key(key)
      expect(found.composite_key).to eq(key)
    end
  end
end
