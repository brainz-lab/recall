class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :projects, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :ingest_key, null: false
      t.string :api_key, null: false

      t.bigint :logs_count, default: 0
      t.bigint :bytes_total, default: 0
      t.integer :retention_days, default: 30

      t.timestamps

      t.index :slug, unique: true
      t.index :ingest_key, unique: true
      t.index :api_key, unique: true
    end
  end
end
