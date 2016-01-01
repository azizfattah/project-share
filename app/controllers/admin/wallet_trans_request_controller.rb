class Admin::WalletTransRequestController < ApplicationController
  before_filter :ensure_is_admin

  def index
  	@wallet_transfer_requests = WalletTransfer.all
  end

  def approve
    transaction = WalletTransfer.find(params[:transaction])
    requester = Person.find(transaction[:person_id])
    samt = transaction.amount_cents * 100
    a = requester.store_credits.last.balance_cents - samt
    if transaction.amount_cents <= requester.balance_cents
      requester.store_credits.create!(:amount_cents => samt, :balance_cents => a , :trans_type => "Add To PayPal Account")
      status = "Approve"
      flash[:notice] = "Amount Added To Requester PayPal Account"
    else
      status= "Rejected"
      flash[:notice] = "Unsuffient balance in wallet"            
    end
    transaction.update_attributes(:status => status)
    redirect_to :back
  end

  def reject
    transaction = WalletTransfer.find(params[:transaction])
    status= "Rejected"
    transaction.update_attributes(:status => status)
    flash[:notice] = "Transaction Rejected" 
    redirect_to :back
  end
end
  