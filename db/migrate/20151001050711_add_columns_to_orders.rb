class AddColumnsToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :express_token, :string
    add_column :orders, :user_id, :integer
    add_column :orders, :price, :decimal
    add_column :orders, :express_payer_id, :string
  end
end
