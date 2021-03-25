class CreateUserObjects < ActiveRecord::Migration[6.1]
  def change
    create_table :user_objects do |t|
      t.text :stored_methods
      t.string :status

      t.timestamps
    end
  end
end
