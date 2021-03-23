class AddLatestMetricIdToScripts < ActiveRecord::Migration[6.1]
  def change
    add_column :scripts, :latest_metric_id, :integer
  end
end
