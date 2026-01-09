class Project < ApplicationRecord
  has_many :log_entries, dependent: :delete_all
  has_many :saved_searches, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true
  validates :ingest_key, presence: true
  validates :api_key, presence: true

  before_validation :generate_slug, on: :create
  before_validation :generate_keys, on: :create

  # Check if this project is linked to Platform
  def platform_linked?
    platform_project_id.present?
  end

  private

  def generate_slug
    self.slug ||= name.parameterize if name
  end

  def generate_keys
    # Only generate Recall-specific keys if not Platform-linked
    return if api_key.present? && api_key.start_with?("sk_live_", "sk_test_")

    self.ingest_key ||= "rcl_ingest_#{SecureRandom.hex(16)}"
    self.api_key ||= "rcl_api_#{SecureRandom.hex(16)}"
  end
end
