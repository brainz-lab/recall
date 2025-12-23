class ConvertLogEntriesToHypertable < ActiveRecord::Migration[8.1]
  def up
    # TimescaleDB requires the time column to be part of any unique index/primary key
    # We need to drop the primary key and recreate as composite key

    # Remove existing primary key
    execute "ALTER TABLE log_entries DROP CONSTRAINT log_entries_pkey;"

    # Create composite primary key with timestamp
    execute "ALTER TABLE log_entries ADD PRIMARY KEY (id, timestamp);"

    # Convert to hypertable
    execute <<-SQL
      SELECT create_hypertable(
        'log_entries',
        'timestamp',
        chunk_time_interval => INTERVAL '1 day',
        migrate_data => true,
        if_not_exists => true
      );
    SQL

    # Enable compression
    execute <<-SQL
      ALTER TABLE log_entries SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'project_id',
        timescaledb.compress_orderby = 'timestamp DESC'
      );
    SQL

    # Compression policy - compress chunks older than 7 days
    execute "SELECT add_compression_policy('log_entries', INTERVAL '7 days', if_not_exists => true);"

    # Retention policy - remove data older than 90 days
    execute "SELECT add_retention_policy('log_entries', INTERVAL '90 days', if_not_exists => true);"
  end

  def down
    execute "SELECT remove_retention_policy('log_entries', if_exists => true);"
    execute "SELECT remove_compression_policy('log_entries', if_exists => true);"
    execute "ALTER TABLE log_entries SET (timescaledb.compress = false);"
  end
end
