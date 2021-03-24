class AddSummaryToScripts < ActiveRecord::Migration[6.1]
  def change
    add_column :scripts, :summary, :string
  end
end
