class AddRetentionToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :retention_days, :integer, default: 90 unless column_exists?(:projects, :retention_days)
    add_column :projects, :archive_enabled, :boolean, default: false unless column_exists?(:projects, :archive_enabled)
    add_column :projects, :last_archived_at, :datetime unless column_exists?(:projects, :last_archived_at)
  end
end
