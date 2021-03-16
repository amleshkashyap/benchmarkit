class AddUserRefToScripts < ActiveRecord::Migration[6.1]
  def change
    add_reference :scripts, :user, null: true, foreign_key: true
  end
end
