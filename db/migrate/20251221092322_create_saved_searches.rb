class CreateSavedSearches < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_searches, id: :uuid do |t|
      t.string :name, null: false
      t.string :query, null: false
      t.references :project, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :saved_searches, [:project_id, :name], unique: true
  end
end
