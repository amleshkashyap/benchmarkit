class AddValidWithResultToCodes < ActiveRecord::Migration[6.1]
  def change
    add_column :codes, :valid_with_result, :string
    add_column :codes, :result_type, :string
  end
end
