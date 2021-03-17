class CreateCodes < ActiveRecord::Migration[6.1]
  def change
    create_table :codes do |t|
      t.string :status
      t.string :description
      t.string :snippet
      t.integer :lines

      t.timestamps
    end
  end
end
