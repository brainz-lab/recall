require "rails_helper"

RSpec.describe LogArchiver, type: :service, timescaledb: true do
  let(:project) { create(:project, :archive_enabled, retention_days: 30) }
  subject(:archiver) { LogArchiver.new(project) }

  describe "#preview" do
    it "returns retention metadata" do
      result = archiver.preview
      expect(result[:retention_days]).to eq(30)
      expect(result[:cutoff_date]).to be_within(5.seconds).of(30.days.ago)
      expect(result).to have_key(:logs_to_archive)
      expect(result).to have_key(:last_archived_at)
    end

    it "counts only logs older than retention_days" do
      create(:log_entry, project: project, timestamp: 31.days.ago)
      create(:log_entry, project: project, timestamp: 29.days.ago)

      result = archiver.preview
      expect(result[:logs_to_archive]).to eq(1)
    end
  end

  describe "#deletable_logs" do
    it "returns log_entries older than retention_days" do
      old   = create(:log_entry, project: project, timestamp: 45.days.ago)
      fresh = create(:log_entry, project: project, timestamp: 5.days.ago)

      deletable = archiver.deletable_logs
      expect(deletable).to include(old)
      expect(deletable).not_to include(fresh)
    end

    it "scopes to the project" do
      other_project = create(:project, :archive_enabled, retention_days: 30)
      old_other = create(:log_entry, project: other_project, timestamp: 45.days.ago)

      expect(archiver.deletable_logs).not_to include(old_other)
    end
  end

  describe "#archive!" do
    context "when archive is not enabled" do
      let(:project) { create(:project, archive_enabled: false, retention_days: 30) }

      it "returns failure" do
        result = archiver.archive!
        expect(result[:success]).to be false
        expect(result[:error]).to eq("Archive not enabled")
      end
    end

    context "when no retention policy is set" do
      let(:project) { create(:project, :archive_enabled, retention_days: nil) }

      it "returns failure" do
        result = archiver.archive!
        expect(result[:success]).to be false
        expect(result[:error]).to eq("No retention policy set")
      end
    end

    context "when there are no logs to archive" do
      it "returns success with zero count" do
        create(:log_entry, project: project, timestamp: 5.days.ago)
        result = archiver.archive!
        expect(result[:success]).to be true
        expect(result[:archived_count]).to eq(0)
        expect(result[:message]).to include("No logs to archive")
      end
    end

    context "when there are logs older than retention_days" do
      let!(:old1) { create(:log_entry, project: project, timestamp: 40.days.ago) }
      let!(:old2) { create(:log_entry, project: project, timestamp: 35.days.ago) }
      let!(:fresh) { create(:log_entry, project: project, timestamp: 10.days.ago) }

      it "deletes old logs and returns count" do
        result = archiver.archive!
        expect(result[:success]).to be true
        expect(result[:archived_count]).to eq(2)
        expect(LogEntry.exists?(old1.id)).to be false
        expect(LogEntry.exists?(old2.id)).to be false
        expect(LogEntry.exists?(fresh.id)).to be true
      end

      it "updates the project's last_archived_at" do
        Timecop.freeze do
          archiver.archive!
          project.reload
          expect(project.last_archived_at).to be_within(2.seconds).of(Time.current)
        end
      end

      it "skips export when export_before_delete is false" do
        result = archiver.archive!(export_before_delete: false)
        expect(result[:export_path]).to be_nil
      end

      it "exports logs to a file when export_before_delete is true" do
        result = archiver.archive!(export_before_delete: true)
        expect(result[:success]).to be true
        expect(result[:export_path]).to be_present
        expect(File.exist?(result[:export_path])).to be true
        # Cleanup
        File.delete(result[:export_path]) if File.exist?(result[:export_path])
      end
    end

    context "when an error occurs" do
      it "returns failure with error message" do
        allow(project).to receive(:update!).and_raise(StandardError, "DB error")
        create(:log_entry, project: project, timestamp: 40.days.ago)

        result = archiver.archive!
        expect(result[:success]).to be false
        expect(result[:error]).to eq("DB error")
      end
    end
  end
end
