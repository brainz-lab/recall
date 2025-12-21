class SavedSearch < ApplicationRecord
  belongs_to :project

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :project_id, message: "already exists for this project" }
  validates :query, presence: true

  scope :ordered, -> { order(updated_at: :desc) }
end
