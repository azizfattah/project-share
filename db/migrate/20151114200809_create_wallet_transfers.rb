class CreateWalletTransfers < ActiveRecord::Migration
  def change
    create_table :wallet_transfers do |t|
      t.integer :amount_cents
      t.string :currency
      t.string :type
      t.string :status
      t.string :trans_no
      t.string :person_id

      t.timestamps
    end
  end
end
