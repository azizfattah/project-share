class AddServiceChargeToTransaction < ActiveRecord::Migration
  def change
    add_column :transactions, :service_charge_in_cent, :integer, after: :shipping_price_cents

  end
end
