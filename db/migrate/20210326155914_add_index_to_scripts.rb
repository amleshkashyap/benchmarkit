class AddIndexToScripts < ActiveRecord::Migration[6.1]
  def change
    add_index :scripts, :name, unique: true
  end
end
