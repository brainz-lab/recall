class TrackUsageJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(project_id:, product:, metric:, count:)
    uri = URI("#{PlatformClient::PLATFORM_URL}/api/v1/usage/track")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = PlatformClient::TIMEOUT
    http.read_timeout = PlatformClient::TIMEOUT

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["X-Service-Key"] = Rails.application.credentials.dig(:service_key) || ENV["SERVICE_KEY"]
    request.body = {
      project_id: project_id,
      product: product,
      metric: metric,
      count: count
    }.to_json

    http.request(request)
  end
end
