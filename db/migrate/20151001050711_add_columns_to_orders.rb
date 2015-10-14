class AddColumnsToOrders < ActiveRecord::Migration

  def up
    create_table :orders do |t|
      t.column :express_token, :string
      t.column :user_id, :integer
      t.column :price, :decimal
      t.column :express_payer_id, :string
    end
  end

end
