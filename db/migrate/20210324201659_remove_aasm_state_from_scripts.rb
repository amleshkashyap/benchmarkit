class RemoveAasmStateFromScripts < ActiveRecord::Migration[6.1]
  def change
    remove_column :scripts, :aasm_state, :string
  end
end
