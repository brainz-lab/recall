class LogEntry < ApplicationRecord
  include Timescaledb::Rails::Model
  include HypertableFindable

  self.primary_key = "id"

  belongs_to :project, counter_cache: :logs_count

  LEVELS = %w[debug info warn error fatal].freeze

  validates :timestamp, presence: true
  validates :level, presence: true, inclusion: { in: LEVELS }

  scope :recent, -> { order(timestamp: :desc) }
  scope :chronological, -> { order(timestamp: :asc) }

  # Get counts by level for a given scope
  def self.counts_by_level
    where(id: all.select(:id)).group(:level).count
  end

  # Get counts for recent time periods
  def self.recent_counts(since: 1.hour.ago)
    where("timestamp >= ?", since).group(:level).count
  end

  # Generate composite key for URL-safe identification (id_timestamp format)
  def composite_key
    "#{id}_#{timestamp.iso8601(6)}"
  end
end
