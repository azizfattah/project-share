# == Schema Information
#
# Table name: wallet_transfers
#
#  id           :integer          not null, primary key
#  amount_cents :integer
#  currency     :string(255)
#  request      :string(255)
#  status       :string(255)
#  trans_no     :string(255)
#  person_id    :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class WalletTransfer < ActiveRecord::Base
  monetize :amount_cents, :allow_nil => true, :with_model_currency => :default_currency
  belongs_to :person
  validates :amount_cents, presence: true
  attr_accessible :amount_cents, :currency, :person_id, :status, :trans_no, :request
  before_create :generate_trans_no

  def generate_trans_no
  	self.trans_no = SecureRandom.base64(15).tr('+/=', '0aZ')
  end
end
