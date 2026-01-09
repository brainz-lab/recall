# frozen_string_literal: true

class FixSolidCacheKeyHashColumn < ActiveRecord::Migration[8.1]
  def up
    # Check if we're connected to the cache database
    return unless connection.table_exists?(:solid_cache_entries)

    # PostgreSQL doesn't allow altering GENERATED columns directly.
    # We need to drop and recreate the column.
    # This is safe for cache - data is ephemeral.

    # First, check if the column is actually a generated column
    result = execute(<<~SQL).first
      SELECT is_generated FROM information_schema.columns
      WHERE table_name = 'solid_cache_entries' AND column_name = 'key_hash'
    SQL

    return unless result && result['is_generated'] == 'ALWAYS'

    # Drop indexes first
    remove_index :solid_cache_entries, name: :index_solid_cache_entries_on_key_hash, if_exists: true
    remove_index :solid_cache_entries, name: :index_solid_cache_entries_on_key_hash_and_byte_size, if_exists: true

    # Truncate the table (cache data is ephemeral)
    execute "TRUNCATE TABLE solid_cache_entries"

    # Drop the generated column
    remove_column :solid_cache_entries, :key_hash

    # Add it back as a regular column
    add_column :solid_cache_entries, :key_hash, :bigint, null: false

    # Recreate indexes
    add_index :solid_cache_entries, :key_hash, unique: true
    add_index :solid_cache_entries, [:key_hash, :byte_size]
  end

  def down
    # No rollback needed - the fix is permanent
  end
end
