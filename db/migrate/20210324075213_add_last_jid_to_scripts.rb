class AddLastJidToScripts < ActiveRecord::Migration[6.1]
  def change
    add_column :scripts, :last_jid, :string
  end
end
