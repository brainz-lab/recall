FactoryBot.define do
  factory :saved_search do
    project
    sequence(:name) { |n| "Saved Search #{n}" }
    query { "level:error" }

    trait :with_data_filter do
      query { "data.user_id:42 level:error" }
    end

    trait :with_time_filter do
      query { "level:warn since:1h" }
    end

    trait :stats_query do
      name { "Error Stats" }
      query { "since:1d | stats by:level" }
    end

    trait :text_search do
      query { '"payment failed" env:production' }
    end
  end
end
