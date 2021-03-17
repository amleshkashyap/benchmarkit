class AddLatestCodeIdToScripts < ActiveRecord::Migration[6.1]
  def change
    add_column :scripts, :latest_code_id, :integer
  end
end
