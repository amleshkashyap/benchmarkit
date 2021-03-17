class AddExecuteFromToMetrics < ActiveRecord::Migration[6.1]
  def change
    add_column :metrics, :execute_from, :string
  end
end
