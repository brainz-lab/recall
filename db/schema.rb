# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_21_102000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"

  create_table "log_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "branch"
    t.string "commit"
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.string "environment"
    t.string "host"
    t.string "level", null: false
    t.text "message"
    t.uuid "project_id", null: false
    t.string "request_id"
    t.string "service"
    t.string "session_id"
    t.datetime "timestamp", null: false
    t.index ["data"], name: "index_log_entries_on_data", opclass: :jsonb_path_ops, using: :gin
    t.index ["message"], name: "index_log_entries_on_message", opclass: :gin_trgm_ops, using: :gin
    t.index ["project_id", "commit"], name: "index_log_entries_on_project_id_and_commit"
    t.index ["project_id", "level"], name: "index_log_entries_on_project_id_and_level"
    t.index ["project_id", "session_id"], name: "index_log_entries_on_project_id_and_session_id"
    t.index ["project_id", "timestamp"], name: "index_log_entries_on_project_id_and_timestamp"
    t.index ["project_id"], name: "index_log_entries_on_project_id"
    t.index ["request_id"], name: "index_log_entries_on_request_id"
    t.index ["session_id"], name: "index_log_entries_on_session_id"
    t.index ["timestamp"], name: "index_log_entries_on_timestamp"
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "api_key", null: false
    t.boolean "archive_enabled", default: false
    t.bigint "bytes_total", default: 0
    t.datetime "created_at", null: false
    t.string "ingest_key", null: false
    t.datetime "last_archived_at"
    t.bigint "logs_count", default: 0
    t.string "name", null: false
    t.integer "retention_days", default: 30
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key"], name: "index_projects_on_api_key", unique: true
    t.index ["ingest_key"], name: "index_projects_on_ingest_key", unique: true
    t.index ["slug"], name: "index_projects_on_slug", unique: true
  end

  create_table "saved_searches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.string "query", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_saved_searches_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_saved_searches_on_project_id"
  end

  add_foreign_key "log_entries", "projects"
  add_foreign_key "saved_searches", "projects"
end
