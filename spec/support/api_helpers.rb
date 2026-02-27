module ApiHelpers
  # Auth using rcl_api_* key (project column)
  def auth_headers(project)
    { "Authorization" => "Bearer #{project.api_key}" }
  end

  # Auth using rcl_ingest_* key (project column)
  def ingest_headers(project)
    { "Authorization" => "Bearer #{project.ingest_key}" }
  end

  # Master key for project provisioning endpoints
  def master_key_headers(key = nil)
    key ||= ENV.fetch("RECALL_MASTER_KEY", "test_master_key_recall")
    { "X-Master-Key" => key }
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
