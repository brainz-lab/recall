class CreateLogEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :log_entries, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.datetime :timestamp, null: false
      t.string :level, null: false
      t.text :message

      t.string :commit
      t.string :branch
      t.string :environment
      t.string :service
      t.string :host

      t.string :request_id
      t.string :session_id

      t.jsonb :data, default: {}

      t.datetime :created_at, null: false
    end

    add_index :log_entries, [:project_id, :timestamp]
    add_index :log_entries, [:project_id, :level]
    add_index :log_entries, [:project_id, :commit]
    add_index :log_entries, [:project_id, :session_id]
    add_index :log_entries, :request_id
    add_index :log_entries, :session_id
    add_index :log_entries, :timestamp

    # GIN index for JSONB queries
    execute "CREATE INDEX index_log_entries_on_data ON log_entries USING GIN (data jsonb_path_ops);"

    # Trigram index for text search on message
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
    execute "CREATE INDEX index_log_entries_on_message ON log_entries USING GIN (message gin_trgm_ops);"
  end
end
