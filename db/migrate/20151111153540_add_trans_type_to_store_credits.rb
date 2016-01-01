class AddTransTypeToStoreCredits < ActiveRecord::Migration
  def change
    add_column :store_credits, :trans_type, :string
  end
end
