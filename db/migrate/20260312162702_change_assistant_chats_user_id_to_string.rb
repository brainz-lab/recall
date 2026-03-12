class ChangeAssistantChatsUserIdToString < ActiveRecord::Migration[8.1]
  def change
    change_column :assistant_chats, :user_id, :string
  end
end
