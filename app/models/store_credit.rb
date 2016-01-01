# == Schema Information
#
# Table name: store_credits
#
#  id             :integer          not null, primary key
#  reason         :string(255)
#  transaction_id :integer
#  balance_cents  :integer
#  amount_cents   :integer
#  currency       :string(255)
#  person_id      :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  trans_type     :string(255)
#

class StoreCredit < ActiveRecord::Base
  belongs_to :person
  attr_accessible :amount_cents, :balance_cents, :currency, :reason, :transaction_id, :person_id, :trans_type
  monetize :balance_cents, :allow_nil => true, :with_model_currency => :default_currency
  monetize :amount_cents, :allow_nil => true, :with_model_currency => :default_currency
end
