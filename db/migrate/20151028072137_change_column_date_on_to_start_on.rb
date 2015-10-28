class ChangeColumnDateOnToStartOn < ActiveRecord::Migration
  def change
    rename_column :booking_infos, :date_on, :start_on
  end
end
