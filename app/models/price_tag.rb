# == Schema Information
#
# Table name: price_tags
#
#  id         :integer          not null, primary key
#  price      :float
#  date       :date
#  listing_id :integer
#  available  :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_price_tags_on_listing_id  (listing_id)
#

class PriceTag < ActiveRecord::Base
  belongs_to :listing
  attr_accessible :available, :date, :price, :listing_id
  validates :date, :listing, presence: true

  def as_json(*args)
    super(except: [:created_at, :updated_at])
  end

end

