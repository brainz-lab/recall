class Project < ApplicationRecord
  has_many :log_entries, dependent: :delete_all
  has_many :saved_searches, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :ingest_key, presence: true, uniqueness: true
  validates :api_key, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create
  before_validation :generate_keys, on: :create

  private

  def generate_slug
    self.slug ||= name.parameterize if name
  end

  def generate_keys
    self.ingest_key ||= "rcl_ingest_#{SecureRandom.hex(16)}"
    self.api_key ||= "rcl_api_#{SecureRandom.hex(16)}"
  end
end
