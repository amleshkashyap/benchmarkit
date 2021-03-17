class CreateMetrics < ActiveRecord::Migration[6.1]
  def change
    create_table :metrics do |t|
      t.string :status
      t.string :description
      t.integer :iterations
      t.float :user_time
      t.float :system_time
      t.float :total_time
      t.float :real_time

      t.timestamps
    end
  end
end
