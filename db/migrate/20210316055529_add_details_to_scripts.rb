class AddDetailsToScripts < ActiveRecord::Migration[6.1]
  def change
    add_column :scripts, :status, :string
    add_column :scripts, :history, :hash
  end
end
