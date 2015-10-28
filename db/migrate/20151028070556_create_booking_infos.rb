class CreateBookingInfos < ActiveRecord::Migration
  def change
    create_table :booking_infos do |t|
      t.integer :listing_id
      t.date :date_on
      t.date :end_on

      t.timestamps
    end
  end
end
