require "rails_helper"

RSpec.describe LogsChannel, type: :channel do
  let(:project) { create(:project) }

  describe "#subscribed" do
    it "streams for the given project" do
      subscribe(project_id: project.id)
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_for(project)
    end

    it "rejects with invalid project_id" do
      expect {
        subscribe(project_id: "nonexistent")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#unsubscribed" do
    it "stops all streams" do
      subscribe(project_id: project.id)
      unsubscribe
      expect(subscription).not_to have_streams
    end
  end

  describe ".broadcast_log" do
    it "broadcasts a log type message" do
      entry = create(:log_entry, project: project)

      expect {
        LogsChannel.broadcast_log(project, entry)
      }.to have_broadcasted_to(project).with(
        hash_including(type: "log")
      )
    end
  end

  describe ".broadcast_session_cleared" do
    it "broadcasts a session_cleared message" do
      expect {
        LogsChannel.broadcast_session_cleared(project, "sess-123", 5)
      }.to have_broadcasted_to(project).with(
        type: "session_cleared",
        session_id: "sess-123",
        deleted_count: 5
      )
    end
  end

  describe ".broadcast_saved_search_created" do
    it "broadcasts with search details" do
      search = create(:saved_search, project: project)

      expect {
        LogsChannel.broadcast_saved_search_created(project, search)
      }.to have_broadcasted_to(project).with(
        hash_including(type: "saved_search_created")
      )
    end
  end

  describe ".broadcast_saved_search_deleted" do
    it "broadcasts with search id" do
      expect {
        LogsChannel.broadcast_saved_search_deleted(project, "search-id-123")
      }.to have_broadcasted_to(project).with(
        type: "saved_search_deleted",
        saved_search_id: "search-id-123"
      )
    end
  end
end
