class WalletTransfersController < ApplicationController
  def index
  end

  def create
  	cur_bal = @current_person.store_credits.last.balance_cents/100
  	trans_bal = params[:wallet_transfer][:amount_cents]
  	if cur_bal >= trans_bal.to_f
	  	@wallet_transfer = @current_person.wallet_transfers.new(params[:wallet_transfer])
	  	@wallet_transfer.status = "pending"
	  	@wallet_transfer.save!
	  	 flash[:notice] = "Request Send to admin"
	  else	 
	  	flash[:notice] = "Insufficient Balance"
  	end
  	redirect_to :back
  end
end
