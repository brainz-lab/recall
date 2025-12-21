# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Helper methods for generating fake data
def random_ip
  "#{rand(1..255)}.#{rand(0..255)}.#{rand(0..255)}.#{rand(1..254)}"
end

def random_email
  domains = %w[gmail.com yahoo.com outlook.com company.com example.org]
  names = %w[john jane mike sarah alex chris pat jordan taylor casey]
  "#{names.sample}#{rand(100..999)}@#{domains.sample}"
end

def random_phone
  "+1-#{rand(200..999)}-#{rand(100..999)}-#{rand(1000..9999)}"
end

# Create or find the test project
project = Project.find_or_create_by!(name: "Test Project") do |p|
  p.description = "Demo project for testing Recall"
end

puts "Using project: #{project.name} (#{project.id})"

# Clear existing logs for fresh seed
project.log_entries.delete_all
puts "Cleared existing logs"

# Configuration
TOTAL_LOGS = 100_000
SERVICES = %w[api auth payments orders notifications workers]
ENVIRONMENTS = %w[production staging]
LEVELS = %w[debug info info info info warn error fatal] # Weighted towards info
BRANCHES = ["main", "main", "main", "feature/checkout", "feature/notifications", "fix/auth-bug"]
COMMITS = 5.times.map { SecureRandom.hex(20) }

# Message templates by service
MESSAGES = {
  "api" => [
    { msg: "Request started", level: "info", data: -> { { method: %w[GET POST PUT DELETE].sample, path: ["/api/v1/users", "/api/v1/orders", "/api/v1/products", "/api/v1/checkout"].sample, ip: random_ip } } },
    { msg: "Request completed", level: "info", data: -> { { status: [200, 201, 204, 400, 401, 404, 500].sample, duration_ms: rand(10..500) } } },
    { msg: "Rate limit exceeded", level: "warn", data: -> { { ip: random_ip, limit: 100, window: "1m" } } },
    { msg: "Invalid request body", level: "error", data: -> { { error: "JSON parse error", field: %w[email amount user_id].sample } } },
    { msg: "Route not found", level: "warn", data: -> { { path: "/api/v1/#{%w[unknown missing invalid].sample}", method: "GET" } } },
  ],
  "auth" => [
    { msg: "User authenticated", level: "info", data: -> { { user_id: "usr_#{SecureRandom.hex(6)}", method: %w[password oauth2 api_key].sample } } },
    { msg: "Authentication failed", level: "warn", data: -> { { reason: ["invalid_password", "account_locked", "token_expired"].sample, attempts: rand(1..5) } } },
    { msg: "Token refreshed", level: "debug", data: -> { { user_id: "usr_#{SecureRandom.hex(6)}", expires_in: 3600 } } },
    { msg: "Session created", level: "info", data: -> { { user_id: "usr_#{SecureRandom.hex(6)}", ip: random_ip } } },
    { msg: "Password reset requested", level: "info", data: -> { { email: random_email } } },
    { msg: "Suspicious login detected", level: "error", data: -> { { user_id: "usr_#{SecureRandom.hex(6)}", ip: random_ip, country: %w[RU CN BR IN].sample } } },
  ],
  "payments" => [
    { msg: "Payment initiated", level: "info", data: -> { { amount: (rand(10..500) + rand).round(2), currency: "USD", order_id: "ord_#{SecureRandom.hex(6)}" } } },
    { msg: "Payment successful", level: "info", data: -> { { transaction_id: "txn_#{SecureRandom.hex(8)}", amount: (rand(10..500) + rand).round(2), gateway: %w[stripe braintree paypal].sample } } },
    { msg: "Payment failed", level: "error", data: -> { { error_code: ["card_declined", "insufficient_funds", "expired_card", "invalid_cvc"].sample, card_last4: rand(1000..9999).to_s } } },
    { msg: "Refund processed", level: "info", data: -> { { refund_id: "ref_#{SecureRandom.hex(6)}", amount: (rand(10..100) + rand).round(2), reason: %w[customer_request duplicate fraud].sample } } },
    { msg: "Gateway timeout", level: "warn", data: -> { { gateway: %w[stripe braintree].sample, latency_ms: rand(5000..30000) } } },
    { msg: "Webhook received", level: "debug", data: -> { { event: ["charge.succeeded", "charge.failed", "refund.created"].sample, webhook_id: "wh_#{SecureRandom.hex(8)}" } } },
  ],
  "orders" => [
    { msg: "Order created", level: "info", data: -> { { order_id: "ord_#{SecureRandom.hex(6)}", items: rand(1..10), total: (rand(20..1000) + rand).round(2) } } },
    { msg: "Order updated", level: "info", data: -> { { order_id: "ord_#{SecureRandom.hex(6)}", status: %w[pending processing shipped delivered].sample } } },
    { msg: "Order cancelled", level: "info", data: -> { { order_id: "ord_#{SecureRandom.hex(6)}", reason: %w[customer_request out_of_stock payment_failed].sample } } },
    { msg: "Inventory check failed", level: "error", data: -> { { product_id: "prod_#{SecureRandom.hex(4)}", requested: rand(1..10), available: 0 } } },
    { msg: "Shipping label generated", level: "debug", data: -> { { order_id: "ord_#{SecureRandom.hex(6)}", carrier: %w[ups fedex usps dhl].sample } } },
  ],
  "notifications" => [
    { msg: "Email sent", level: "info", data: -> { { to: random_email, template: %w[welcome order_confirmation password_reset].sample } } },
    { msg: "Email delivery failed", level: "error", data: -> { { to: random_email, error: ["invalid_email", "mailbox_full", "blocked"].sample } } },
    { msg: "Push notification sent", level: "info", data: -> { { user_id: "usr_#{SecureRandom.hex(6)}", type: %w[order_update promo reminder].sample } } },
    { msg: "SMS sent", level: "info", data: -> { { phone: random_phone, type: "verification" } } },
    { msg: "Notification queued", level: "debug", data: -> { { channel: %w[email push sms].sample, scheduled_for: (Time.current + rand(1..24).hours).iso8601 } } },
  ],
  "workers" => [
    { msg: "Job started", level: "info", data: -> { { job_class: %w[ProcessOrderJob SendEmailJob SyncInventoryJob GenerateReportJob].sample, job_id: SecureRandom.uuid } } },
    { msg: "Job completed", level: "info", data: -> { { job_class: %w[ProcessOrderJob SendEmailJob SyncInventoryJob].sample, duration_ms: rand(100..5000) } } },
    { msg: "Job failed", level: "error", data: -> { { job_class: %w[ProcessOrderJob SendEmailJob].sample, error: ["Timeout::Error", "Redis::ConnectionError", "ActiveRecord::RecordNotFound"].sample, attempts: rand(1..3) } } },
    { msg: "Job retrying", level: "warn", data: -> { { job_class: %w[ProcessOrderJob SendEmailJob].sample, attempt: rand(2..5), max_attempts: 5 } } },
    { msg: "Queue depth warning", level: "warn", data: -> { { queue: %w[default critical low].sample, depth: rand(100..1000) } } },
    { msg: "Worker heartbeat", level: "debug", data: -> { { worker_id: "worker-#{rand(1..5)}", memory_mb: rand(100..500), cpu_percent: rand(10..90) } } },
  ]
}

# Generate request traces (groups of related logs)
def generate_request_trace(base_time, request_id)
  env = ENVIRONMENTS.sample
  branch = BRANCHES.sample
  commit = COMMITS.sample
  session_id = "sess_#{SecureRandom.hex(8)}"

  # Typical request flow
  flow = [
    { service: "api", msg: "Request started", level: "info", data: { method: "POST", path: "/api/v1/checkout", ip: random_ip } },
    { service: "auth", msg: "User authenticated", level: "info", data: { user_id: "usr_#{SecureRandom.hex(6)}", method: "bearer_token" } },
  ]

  # Add service-specific logs
  case rand(3)
  when 0 # Successful payment flow
    flow += [
      { service: "orders", msg: "Order created", level: "info", data: { order_id: "ord_#{SecureRandom.hex(6)}", items: rand(1..5), total: (rand(50..500) + rand).round(2) } },
      { service: "payments", msg: "Payment initiated", level: "info", data: { amount: (rand(50..500) + rand).round(2), currency: "USD" } },
      { service: "payments", msg: "Payment successful", level: "info", data: { transaction_id: "txn_#{SecureRandom.hex(8)}", gateway: "stripe" } },
      { service: "notifications", msg: "Email sent", level: "info", data: { template: "order_confirmation" } },
      { service: "api", msg: "Request completed", level: "info", data: { status: 200, duration_ms: rand(200..800) } },
    ]
  when 1 # Failed payment flow
    flow += [
      { service: "orders", msg: "Order created", level: "info", data: { order_id: "ord_#{SecureRandom.hex(6)}", items: rand(1..3) } },
      { service: "payments", msg: "Payment initiated", level: "info", data: { amount: (rand(50..200) + rand).round(2), currency: "USD" } },
      { service: "payments", msg: "Gateway timeout", level: "warn", data: { gateway: "stripe", latency_ms: rand(5000..10000) } },
      { service: "payments", msg: "Payment failed", level: "error", data: { error_code: "card_declined", card_last4: rand(1000..9999).to_s } },
      { service: "api", msg: "Request completed", level: "info", data: { status: 422, duration_ms: rand(5000..12000) } },
    ]
  when 2 # Auth failure flow
    flow = [
      { service: "api", msg: "Request started", level: "info", data: { method: "POST", path: "/api/v1/login" } },
      { service: "auth", msg: "Authentication failed", level: "warn", data: { reason: "invalid_password", attempts: rand(1..3) } },
      { service: "api", msg: "Request completed", level: "info", data: { status: 401, duration_ms: rand(50..150) } },
    ]
  end

  logs = []
  flow.each_with_index do |log_data, i|
    logs << {
      timestamp: base_time + (i * rand(50..200) / 1000.0).seconds,
      level: log_data[:level],
      message: log_data[:msg],
      service: log_data[:service],
      request_id: request_id,
      session_id: session_id,
      environment: env,
      branch: branch,
      commit: commit,
      data: log_data[:data]
    }
  end
  logs
end

# Generate logs
logs_to_create = []
base_time = 24.hours.ago

puts "Generating #{TOTAL_LOGS} logs..."

# Generate ~30% as request traces
trace_count = (TOTAL_LOGS * 0.3 / 5).to_i # Average 5 logs per trace
print "Generating #{trace_count} request traces..."
trace_count.times do |i|
  request_id = "req_#{SecureRandom.hex(8)}"
  trace_time = base_time + rand(0..86400).seconds
  trace_logs = generate_request_trace(trace_time, request_id)
  logs_to_create.concat(trace_logs)
  print "." if i % 500 == 0
end
puts " done!"

# Generate remaining individual logs
remaining = TOTAL_LOGS - logs_to_create.size
print "Generating #{remaining} individual logs..."
remaining.times do |i|
  service = SERVICES.sample
  template = MESSAGES[service].sample
  level = template[:level] || LEVELS.sample

  # Override level occasionally for variety
  level = LEVELS.sample if rand < 0.3

  logs_to_create << {
    timestamp: base_time + rand(0..86400).seconds,
    level: level,
    message: template[:msg],
    service: service,
    request_id: rand < 0.4 ? "req_#{SecureRandom.hex(8)}" : nil,
    session_id: rand < 0.5 ? "sess_#{SecureRandom.hex(8)}" : nil,
    environment: ENVIRONMENTS.sample,
    branch: BRANCHES.sample,
    commit: COMMITS.sample,
    data: template[:data].call
  }
  print "." if i % 5000 == 0
end
puts " done!"

# Bulk insert for performance
batch_size = 1000
total_batches = (logs_to_create.size / batch_size.to_f).ceil
puts "Inserting #{logs_to_create.size} logs in #{total_batches} batches..."
logs_to_create.each_slice(batch_size).with_index do |batch, i|
  project.log_entries.insert_all(
    batch.map { |log| log.merge(project_id: project.id) }
  )
  print "\rInserting batch #{i + 1}/#{total_batches}..."
end
puts " done!"

# Update project logs count
project.update_column(:logs_count, project.log_entries.count)

puts "Done! Created #{project.log_entries.count} logs for project '#{project.name}'"
puts "Sample queries:"
puts "  level:error since:24h"
puts "  service:payments level:error"
puts "  \"Payment failed\" since:1h"
