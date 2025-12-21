class LogEntry < ApplicationRecord
  belongs_to :project, counter_cache: :logs_count

  LEVELS = %w[debug info warn error fatal].freeze

  validates :timestamp, presence: true
  validates :level, presence: true, inclusion: { in: LEVELS }

  default_scope { order(timestamp: :desc) }

  # Get counts by level for a given scope
  def self.counts_by_level
    unscoped.where(id: all.select(:id)).group(:level).count
  end

  # Get counts for recent time periods
  def self.recent_counts(since: 1.hour.ago)
    unscope(:order).where("timestamp >= ?", since).group(:level).count
  end
end
