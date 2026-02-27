FactoryBot.define do
  factory :log_entry do
    project
    timestamp { Time.current }
    level     { "info" }
    message   { "Application started successfully" }
    environment { "production" }
    service   { "web" }
    data      { {} }

    trait :debug do
      level   { "debug" }
      message { "Debug: variable state checked" }
    end

    trait :info do
      level   { "info" }
      message { "User signed in" }
    end

    trait :warn do
      level   { "warn" }
      message { "Response time exceeded threshold" }
    end

    trait :error do
      level   { "error" }
      message { "Payment processing failed" }
    end

    trait :fatal do
      level   { "fatal" }
      message { "Database connection lost" }
    end

    trait :with_request do
      request_id { "req-#{SecureRandom.hex(8)}" }
    end

    trait :with_session do
      session_id { "sess-#{SecureRandom.hex(8)}" }
    end

    trait :with_data do
      data { { "user_id" => 42, "action" => "checkout", "amount" => 99.99 } }
    end

    trait :old do
      timestamp { 100.days.ago }
    end
  end
end
