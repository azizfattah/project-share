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

require 'spec_helper'

describe PriceTag do
  pending "add some examples to (or delete) #{__FILE__}"
end
