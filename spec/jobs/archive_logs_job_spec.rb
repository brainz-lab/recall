require "rails_helper"

RSpec.describe ArchiveLogsJob, type: :job do
  describe "#perform" do
    context "with a specific project_id" do
      let(:project) { create(:project, :archive_enabled, retention_days: 30) }

      it "runs LogArchiver for the given project" do
        archiver = instance_double(LogArchiver, archive!: { success: true, archived_count: 5, message: "Archived 5 logs" })
        allow(LogArchiver).to receive(:new).with(project).and_return(archiver)

        described_class.new.perform(project.id)

        expect(LogArchiver).to have_received(:new).with(project)
        expect(archiver).to have_received(:archive!).with(export_before_delete: false)
      end

      it "raises ActiveRecord::RecordNotFound for an unknown project_id" do
        expect {
          described_class.new.perform(0)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "without a project_id (global run)" do
      let!(:enabled_project1)  { create(:project, :archive_enabled, retention_days: 30) }
      let!(:enabled_project2)  { create(:project, :archive_enabled, retention_days: 7) }
      let!(:disabled_project)  { create(:project, archive_enabled: false, retention_days: 30) }

      it "archives all projects with archive_enabled" do
        archiver1 = instance_double(LogArchiver, archive!: { success: true, archived_count: 0, message: "No logs" })
        archiver2 = instance_double(LogArchiver, archive!: { success: true, archived_count: 0, message: "No logs" })

        allow(LogArchiver).to receive(:new).with(enabled_project1).and_return(archiver1)
        allow(LogArchiver).to receive(:new).with(enabled_project2).and_return(archiver2)
        allow(LogArchiver).to receive(:new).with(disabled_project).and_return(instance_double(LogArchiver))

        described_class.new.perform

        expect(LogArchiver).to have_received(:new).with(enabled_project1)
        expect(LogArchiver).to have_received(:new).with(enabled_project2)
        expect(LogArchiver).not_to have_received(:new).with(disabled_project)
      end

      it "logs an error when archiving fails without raising" do
        allow(LogArchiver).to receive(:new).and_return(
          instance_double(LogArchiver, archive!: { success: false, error: "DB error" })
        )

        expect {
          described_class.new.perform
        }.not_to raise_error
      end
    end
  end
end
