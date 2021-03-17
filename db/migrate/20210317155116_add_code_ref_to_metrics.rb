class AddCodeRefToMetrics < ActiveRecord::Migration[6.1]
  def change
    add_reference :metrics, :code, null: false, foreign_key: true
  end
end
