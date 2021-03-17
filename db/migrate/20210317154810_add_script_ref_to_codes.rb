class AddScriptRefToCodes < ActiveRecord::Migration[6.1]
  def change
    add_reference :codes, :script, null: false, foreign_key: true
  end
end
