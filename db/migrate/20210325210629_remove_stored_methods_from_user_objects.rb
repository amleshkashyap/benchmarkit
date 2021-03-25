class RemoveStoredMethodsFromUserObjects < ActiveRecord::Migration[6.1]
  def change
    remove_column :user_objects, :stored_methods, :text
  end
end
