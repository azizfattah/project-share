class CreatePriceTags < ActiveRecord::Migration
  def change
    create_table :price_tags do |t|
      t.float :price
      t.date :date
      t.references :listing
      t.boolean :available, default: true

      t.timestamps
    end
    add_index :price_tags, :listing_id
  end
end
