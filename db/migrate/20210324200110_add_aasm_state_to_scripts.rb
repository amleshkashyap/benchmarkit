class AddAasmStateToScripts < ActiveRecord::Migration[6.1]
  def change
    add_column :scripts, :aasm_state, :string
  end
end
