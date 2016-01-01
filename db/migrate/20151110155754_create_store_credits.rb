class CreateStoreCredits < ActiveRecord::Migration
  def change
    create_table :store_credits do |t|
      t.string :reason
      t.integer :transaction_id
      t.integer :balance_cents
      t.integer :amount_cents
      t.string :currency
      t.string :person_id

      t.timestamps
    end
  end
end
