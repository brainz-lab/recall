# frozen_string_literal: true

class FixSolidCacheByteSizeColumn < ActiveRecord::Migration[8.1]
  def up
    # Check if we're connected to the cache database
    return unless connection.table_exists?(:solid_cache_entries)

    # Check if byte_size is a generated column
    result = execute(<<~SQL).first
      SELECT is_generated FROM information_schema.columns
      WHERE table_name = 'solid_cache_entries' AND column_name = 'byte_size'
    SQL

    return unless result && result['is_generated'] == 'ALWAYS'

    # Drop indexes that depend on byte_size
    remove_index :solid_cache_entries, name: :index_solid_cache_entries_on_key_hash_and_byte_size, if_exists: true

    # Truncate the table (cache data is ephemeral)
    execute "TRUNCATE TABLE solid_cache_entries"

    # Drop the generated column
    remove_column :solid_cache_entries, :byte_size

    # Add it back as a regular column
    add_column :solid_cache_entries, :byte_size, :integer, null: false, default: 0

    # Recreate the index
    add_index :solid_cache_entries, [ :key_hash, :byte_size ]
  end

  def down
    # No rollback needed - the fix is permanent
  end
end
