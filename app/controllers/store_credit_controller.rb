class StoreCreditController < ApplicationController
  def wallet
    @wallet_transfer = @current_person.wallet_transfers.new
  end

  def create
  end

  def wallet_statements
    @my_wallet_transfer = @current_person.wallet_transfers
  end

  def add_to_wallet
    reset_session_params
  	wallet_transfer = @current_person.wallet_transfers.new(params[:wallet_transfer])
  	wallet_transfer.save!
    amt =  wallet_transfer.amount_cents * 100
    session[:amount] = wallet_transfer.amount_cents
    response = EXPRESS_GATEWAY.setup_purchase(amt.to_f,
                                            ip: request.remote_ip,
                                            return_url: add_to_wallet_success_url,
                                            cancel_return_url: "http://esignature.lvh.me:3000/",
                                            currency: "USD",
                                            allow_guest_checkout: true,
                                            items: [{name: @current_person.username, description: wallet_transfer.request, amount: amt}]
    )
    redirect_to EXPRESS_GATEWAY.redirect_url_for(response.token)
  end

  def success
    samt = session[:amount] *100
    a = @current_person.balance_cents + samt
    if (params[:token].present? && params[:PayerID].present?)
      @current_person.store_credits.create!(:amount_cents => samt, :balance_cents => a , :trans_type => "Add To Wallet")
      @current_person.wallet_transfers.last.update_attributes(:status => "Added to wallet")
      flash[:notice] = "Amount Added To Your Wallet"
    else
      @current_person.wallet_transfers.last.update_attributes(:status => "Unsuccesfull")
      flash[:notice] = "Payment Unsuccesfull Try Again"
    end
      reset_session_params
      redirect_to :action => 'wallet'
  end

  def reset_session_params
    session[:number_of_days] = nil
    session[:listing_id] = nil
    session[:amount] = nil
    session[:service_charge] = nil
    session[:number_of_days] = nil
    session[:start_date] = nil
    session[:end_date] = nil
  end
end
