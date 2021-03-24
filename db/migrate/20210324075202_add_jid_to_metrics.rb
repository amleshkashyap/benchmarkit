class AddJidToMetrics < ActiveRecord::Migration[6.1]
  def change
    add_column :metrics, :jid, :string
  end
end
