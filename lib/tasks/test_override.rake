# Skip tailwindcss build in test environment
if Rails.env.test?
  Rake::Task["tailwindcss:build"].clear if Rake::Task.task_defined?("tailwindcss:build")
  task "tailwindcss:build" do
    # Skip in test
  end
end
