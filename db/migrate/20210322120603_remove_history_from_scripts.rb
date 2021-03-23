class RemoveHistoryFromScripts < ActiveRecord::Migration[6.1]
  def change
    remove_column :scripts, :history, :string
  end
end
