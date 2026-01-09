class AddPlatformFieldsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :platform_project_id, :uuid
    add_column :projects, :platform_organization_id, :uuid
    add_column :projects, :environment, :string, default: "production"

    add_index :projects, :platform_project_id, unique: true, where: "platform_project_id IS NOT NULL"
  end
end
