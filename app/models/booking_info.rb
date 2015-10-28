# == Schema Information
#
# Table name: booking_infos
#
#  id         :integer          not null, primary key
#  listing_id :integer
#  start_on   :date
#  end_on     :date
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class BookingInfo < ActiveRecord::Base
  attr_accessible :start_on, :end_on, :listing_id
end
