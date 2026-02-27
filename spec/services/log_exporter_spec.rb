require "rails_helper"

RSpec.describe LogExporter, type: :service, timescaledb: true do
  let(:project) { create(:project) }

  before do
    create(:log_entry, project: project, level: "error",
           message: "Payment failed", environment: "production",
           service: "payments", timestamp: 1.hour.ago)
    create(:log_entry, project: project, level: "info",
           message: "User signed in", environment: "staging",
           service: "web", timestamp: 30.minutes.ago)
  end

  describe "#filename" do
    it "includes the project slug and format extension" do
      exporter = LogExporter.new(project, format: :json)
      expect(exporter.filename).to match(/\A#{project.name.parameterize}_logs_\d{8}_\d{6}\.json\z/)
    end

    it "uses csv extension for csv format" do
      exporter = LogExporter.new(project, format: :csv)
      expect(exporter.filename).to end_with(".csv")
    end
  end

  describe "#content_type" do
    it "returns application/json for json format" do
      exporter = LogExporter.new(project, format: :json)
      expect(exporter.content_type).to eq("application/json")
    end

    it "returns text/csv for csv format" do
      exporter = LogExporter.new(project, format: :csv)
      expect(exporter.content_type).to eq("text/csv")
    end
  end

  describe "#count" do
    it "returns the number of matching logs" do
      exporter = LogExporter.new(project)
      expect(exporter.count).to eq(2)
    end

    it "respects query filters" do
      exporter = LogExporter.new(project, query: "level:error")
      expect(exporter.count).to eq(1)
    end
  end

  describe "#export" do
    describe "JSON format" do
      subject(:exporter) { LogExporter.new(project, format: :json) }

      it "returns valid JSON" do
        json = exporter.export
        expect { JSON.parse(json) }.not_to raise_error
      end

      it "includes all project log entries" do
        data = JSON.parse(exporter.export)
        expect(data.size).to eq(2)
      end
    end

    describe "CSV format" do
      subject(:exporter) { LogExporter.new(project, format: :csv) }

      it "returns a string with CSV headers" do
        csv = exporter.export
        expect(csv).to include("id")
        expect(csv).to include("timestamp")
        expect(csv).to include("level")
        expect(csv).to include("message")
      end

      it "includes log data rows" do
        csv = exporter.export
        expect(csv).to include("error")
        expect(csv).to include("Payment failed")
      end
    end

    describe "with query filter" do
      it "exports only matching logs" do
        exporter = LogExporter.new(project, query: "level:error", format: :json)
        data = JSON.parse(exporter.export)
        expect(data.size).to eq(1)
        expect(data.first["level"]).to eq("error")
      end
    end

    describe "with since filter" do
      it "exports only logs within the time window" do
        exporter = LogExporter.new(project, since: "45m", format: :json)
        data = JSON.parse(exporter.export)
        expect(data.size).to eq(1)
        expect(data.first["message"]).to eq("User signed in")
      end
    end

    describe "with until_time filter" do
      it "exports only logs up to the given time" do
        exporter = LogExporter.new(project, until_time: 45.minutes.ago.iso8601, format: :json)
        data = JSON.parse(exporter.export)
        expect(data.size).to eq(1)
        expect(data.first["message"]).to eq("Payment failed")
      end
    end

    describe "defaults to JSON for unknown format" do
      it "returns JSON when format is not csv" do
        exporter = LogExporter.new(project, format: :xml)
        expect { JSON.parse(exporter.export) }.not_to raise_error
      end
    end
  end
end
