class TransactionsController < ApplicationController

  before_filter only: [:show] do |controller|
    controller.ensure_logged_in t("layouts.notifications.you_must_log_in_to_view_your_inbox")
  end

  before_filter do |controller|
    controller.ensure_logged_in t("layouts.notifications.you_must_log_in_to_do_a_transaction")
  end

  MessageForm = Form::Message

  TransactionForm = EntityUtils.define_builder(
      [:listing_id, :fixnum, :to_integer, :mandatory],
      [:message, :string],
      [:quantity, :fixnum, :to_integer, default: 1],
      [:start_on, transform_with: ->(v) { Maybe(v).map { |d| TransactionViewUtils.parse_booking_date(d) }.or_else(nil) }],
      [:end_on, transform_with: ->(v) { Maybe(v).map { |d| TransactionViewUtils.parse_booking_date(d) }.or_else(nil) }]
  )

  def transaction_all
    @transactions =  Transaction.all
  end
  def pay_from_wallet
    wallet_bal = @current_person.store_credits.last.balance_cents
    bal = @current_person.store_credits.last.balance_cents - session[:amount].to_i
    if bal < 0     
      a=@current_person.store_credits.new(:amount_cents => params[:amount], trans_type: "wallet_deduction", balance_cents: 000)
        a.save!
        new_amount= bal.abs
        session[:amount] = new_amount
        listing = Listing.find(session[:listing_id].to_f)
        response = EXPRESS_GATEWAY.setup_purchase(session[:amount].to_f,
                                            ip: request.remote_ip,
                                            return_url: "http://esignature.lvh.me:3000/en/transactions/status_wallet",
                                            cancel_return_url: "http://esignature.lvh.me:3000/",
                                            currency: "USD",
                                            allow_guest_checkout: true,
                                            items: [{name: listing.title, description: listing.description, quantity: session[:number_of_days], amount: ((session[:amount] - session[:service_charge]).to_f/session[:number_of_days])},
                                            {name: "Service Charge", amount: session[:service_charge]}
                                              ]
    )
    redirect_to EXPRESS_GATEWAY.redirect_url_for(response.token)
      else
        a=@current_person.store_credits.new(:amount_cents => params[:amount], trans_type: "wallet_deduction", balance_cents: bal)
        a.save!
        redirect_to status_person_transactions_path(person_id: @current_person.id, :payed_from_wallet => 1)
    end
  end

  def status_wallet
    if (params[:token].present? && params[:PayerID].present?)
      listing = Listing.find(session[:listing_id].to_f)
      token = params[:token]
      @response = EXPRESS_GATEWAY.details_for(token).params
      express_purchase_options = {
          :ip => request.remote_ip,
          :token => params[:token],
          :payer_id => params[:PayerID],
          items: [{name: listing.title + "( Start Date: "+ session[:start_date] + "   End Date: "+ session[:end_date] + ")", description: listing.description, quantity: session[:number_of_days], amount: session[:amount] - session[:service_charge]},
                  {name: "Service Charge", amount: session[:service_charge]}
          ]
      }

      response = EXPRESS_GATEWAY.purchase(session[:amount].to_f, express_purchase_options)

      if response.message == "Success"
        listing = Listing.find(session[:listing_id].to_f)
        BookingInfo.create!(listing_id: listing.id, start_on:  session[:start_date].to_date, end_on:  session[:end_date].to_date)
        render 'status_wallet'
      else
        render 'status_error'
      end
      reset_session_params
    elsif params[:payed_from_wallet]
      listing = Listing.find(session[:listing_id].to_f)
      BookingInfo.create!(listing_id: listing.id, start_on:  session[:start_date].to_date, end_on:  session[:end_date].to_date)
      reset_session_params
    else
      reset_session_params
      redirect_to  homepage_without_locale_path
    end

  end

  def new
    Result.all(
    ->() {
      fetch_data(params[:listing_id])
    },
    ->((listing_id, listing_model)) {
      ensure_can_start_transactions(listing_model: listing_model, current_user: @current_user, current_community: @current_community)
    }
    ).on_success { |((listing_id, listing_model, author_model, process, gateway))|
      booking = listing_model.unit_type == :day

      transaction_params = HashUtils.symbolize_keys({listing_id: listing_model.id}.merge(params.slice(:start_on, :end_on, :quantity, :delivery)))

      if transaction_params[:start_on].present? && transaction_params[:end_on].present?
        start_date = Date.parse(transaction_params[:start_on])
        session[:start_date] = transaction_params[:start_on]

        end_date = Date.parse(transaction_params[:end_on])
        session[:end_date] = transaction_params[:end_on]

        number_of_days = end_date.mjd - start_date.mjd + 1

        session[:number_of_days] = number_of_days

        @listing = Listing.find(params[:listing_id])

        total_amount_in_cent = number_of_days * @listing.price_cents

        community_id = PaypalAccount.where(active: true).where("paypal_accounts.community_id IS NOT NULL && paypal_accounts.person_id IS NULL").first.community_id

        commision_from_seller = PaymentSettings.where(active: true).where(community_id: community_id).first.commission_from_seller # service charge from seller

        service_charge_in_cent = total_amount_in_cent * commision_from_seller / 100

        @service_charge = service_charge_in_cent / 100

        total_amount_in_cent = total_amount_in_cent + service_charge_in_cent

        session[:amount] = total_amount_in_cent
        session[:service_charge] = service_charge_in_cent

      end

      if params[:listing_id].present?
        session[:listing_id] = params[:listing_id]
      end

      case [process[:process], gateway, booking]
        when matches([:none])
          render_free(listing_model: listing_model, author_model: author_model, community: @current_community, params: transaction_params)
        when matches([:preauthorize, __, true])
          redirect_to book_path(transaction_params)
        when matches([:preauthorize, :paypal])
          redirect_to initiate_order_path(transaction_params)
        when matches([:preauthorize, :braintree])
          redirect_to preauthorize_payment_path(transaction_params)
        when matches([:postpay])
          redirect_to post_pay_listing_path(transaction_params)
        else
          opts = "listing_id: #{listing_id}, payment_gateway: #{gateway}, payment_process: #{process}, booking: #{booking}"
          raise ArgumentError.new("Can not find new transaction path to #{opts}")
      end
    }.on_error { |error_msg, data|
      flash[:error] = Maybe(data)[:error_tr_key].map { |tr_key| t(tr_key) }.or_else("Could not start a transaction, error message: #{error_msg}")
      redirect_to (session[:return_to_content] || root)
    }
  end

  def express_checkout

    listing = Listing.find(session[:listing_id].to_f)

    response = EXPRESS_GATEWAY.setup_purchase(session[:amount].to_f,
                                              ip: request.remote_ip,
                                              return_url: "http://esignature.lvh.me:3000/en/transactions/status",
                                              cancel_return_url: "http://esignature.lvh.me:3000/",
                                              currency: "USD",
                                              allow_guest_checkout: true,
                                              items: [{name: listing.title, description: listing.description, quantity: session[:number_of_days], amount: listing.price_cents},
                                                      {name: "Service Charge", amount: session[:service_charge]}
                                              ]
    )
    redirect_to EXPRESS_GATEWAY.redirect_url_for(response.token)

  end

  def status
    if (params[:token].present? && params[:PayerID].present?)
      listing = Listing.find(session[:listing_id].to_f)
      token = params[:token]
      @response = EXPRESS_GATEWAY.details_for(token).params
      express_purchase_options = {
          :ip => request.remote_ip,
          :token => params[:token],
          :payer_id => params[:PayerID],
          items: [{name: listing.title + "( Start Date: "+ session[:start_date] + "   End Date: "+ session[:end_date] + ")", description: listing.description, quantity: session[:number_of_days], amount: listing.price_cents},
                  {name: "Service Charge", amount: session[:service_charge]}
          ]
      }
      response = EXPRESS_GATEWAY.purchase(session[:amount].to_f, express_purchase_options)
      if response.message == "Success"
        listing = Listing.find(session[:listing_id].to_f)
        BookingInfo.create!(listing_id: listing.id, start_on:  session[:start_date].to_date, end_on:  session[:end_date].to_date)
        render 'status'
      else
        render 'status_error'
      end
      reset_session_params
    else
      reset_session_params
      redirect_to  homepage_without_locale_path
    end

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

  def express_token=(token)
    self[:express_token] = token
    if new_record? && !token.blank?
      # you can dump details var if you need more info from buyer
      details = EXPRESS_GATEWAY.details_for(token)
      self.express_payer_id = details.payer_id
    end
  end


  def express_purchase_options params
    {
        :ip => ip,
        :token => params[:token],
        :payer_id => express_payer_id
    }
  end

  def create
    Result.all(
    ->() {
      TransactionForm.validate(params)
    },
    ->(form) {
      fetch_data(form[:listing_id])
    },
    ->(form, (_, _, _, process)) {
      validate_form(form, process)
    },
    ->(_, (listing_id, listing_model), _) {
      ensure_can_start_transactions(listing_model: listing_model, current_user: @current_user, current_community: @current_community)
    },
    ->(form, (listing_id, listing_model, author_model, process, gateway), _, _) {
      booking_fields = Maybe(form).slice(:start_on, :end_on).select { |booking| booking.values.all? }.or_else({})

      quantity = Maybe(booking_fields).map { |b| DateUtils.duration_days(b[:start_on], b[:end_on]) }.or_else(form[:quantity])

      TransactionService::Transaction.create(
          {
              transaction: {
                  community_id: @current_community.id,
                  listing_id: listing_id,
                  listing_title: listing_model.title,
                  starter_id: @current_user.id,
                  listing_author_id: author_model.id,
                  unit_type: listing_model.unit_type,
                  unit_price: listing_model.price,
                  unit_tr_key: listing_model.unit_tr_key,
                  listing_quantity: quantity,
                  content: form[:message],
                  booking_fields: booking_fields,
                  payment_gateway: process[:process] == :none ? :none : gateway, # TODO This is a bit awkward
                  payment_process: process[:process],
                  service_charge_in_cent: session[:service_charge]
              }
          })
    }
    ).on_success { |(_, (_, _, _, process), _, _, tx)|
      after_create_actions!(process: process, transaction: tx[:transaction], community_id: @current_community.id)
      flash[:notice] = after_create_flash(process: process) # add more params here when needed
      express_checkout
      # redirect_to after_create_redirect(process: process, starter_id: @current_user.id, transaction: tx[:transaction]) # add more params here when needed
    }.on_error { |error_msg, data|
      flash[:error] = Maybe(data)[:error_tr_key].map { |tr_key| t(tr_key) }.or_else("Could not start a transaction, error message: #{error_msg}")
      redirect_to (session[:return_to_content] || root)
    }
  end

  def show
    m_participant =
        Maybe(
            MarketplaceService::Transaction::Query.transaction_with_conversation(
                transaction_id: params[:id],
                person_id: @current_user.id,
                community_id: @current_community.id))
            .map { |tx_with_conv| [tx_with_conv, :participant] }

    m_admin =
        Maybe(@current_user.has_admin_rights_in?(@current_community))
            .select { |can_show| can_show }
            .map {
          MarketplaceService::Transaction::Query.transaction_with_conversation(
              transaction_id: params[:id],
              community_id: @current_community.id)
        }
            .map { |tx_with_conv| [tx_with_conv, :admin] }

    transaction_conversation, role = m_participant.or_else { m_admin.or_else([]) }

    tx = TransactionService::Transaction.get(community_id: @current_community.id, transaction_id: params[:id])
             .maybe()
             .or_else(nil)

    unless tx.present? && transaction_conversation.present?
      flash[:error] = t("layouts.notifications.you_are_not_authorized_to_view_this_content")
      return redirect_to root
    end

    tx_model = Transaction.where(id: tx[:id]).first
    conversation = transaction_conversation[:conversation]
    listing = Listing.where(id: tx[:listing_id]).first

    messages_and_actions = TransactionViewUtils::merge_messages_and_transitions(
        TransactionViewUtils.conversation_messages(conversation[:messages], @current_community.name_display_type),
        TransactionViewUtils.transition_messages(transaction_conversation, conversation, @current_community.name_display_type))

    MarketplaceService::Transaction::Command.mark_as_seen_by_current(params[:id], @current_user.id)

    is_author =
        if role == :admin
          true
        else
          listing.author_id == @current_user.id
        end

    render "transactions/show", locals: {
                                  messages: messages_and_actions.reverse,
                                  transaction: tx,
                                  listing: listing,
                                  transaction_model: tx_model,
                                  conversation_other_party: person_entity_with_url(conversation[:other_person]),
                                  is_author: is_author,
                                  role: role,
                                  message_form: MessageForm.new({sender_id: @current_user.id, conversation_id: conversation[:id]}),
                                  message_form_action: person_message_messages_path(@current_user, :message_id => conversation[:id]),
                                  price_break_down_locals: price_break_down_locals(tx)
                              }
  end

  def op_status
    process_token = params[:process_token]

    resp = Maybe(process_token)
               .map { |ptok| paypal_process.get_status(ptok) }
               .select(&:success)
               .data
               .or_else(nil)

    if resp
      render :json => resp
    else
      redirect_to error_not_found_path
    end
  end

  def person_entity_with_url(person_entity)
    person_entity.merge({
                            url: person_path(id: person_entity[:username]),
                            display_name: PersonViewUtils.person_entity_display_name(person_entity, @current_community.name_display_type)})
  end

  def paypal_process
    PaypalService::API::Api.process
  end

  private

  def ensure_can_start_transactions(listing_model:, current_user:, current_community:)
    error =
        if listing_model.closed?
          "layouts.notifications.you_cannot_reply_to_a_closed_offer"
        elsif listing_model.author == current_user
          "layouts.notifications.you_cannot_send_message_to_yourself"
        elsif !listing_model.visible_to?(current_user, current_community)
          "layouts.notifications.you_are_not_authorized_to_view_this_content"
        else
          nil
        end

    if error
      Result::Error.new(error, {error_tr_key: error})
    else
      Result::Success.new
    end
  end

  def after_create_flash(process:)
    case process[:process]
      when :none
        t("layouts.notifications.message_sent")
      else
        raise NotImplementedError.new("Not implemented for process #{process}")
    end
  end

  def after_create_redirect(process:, starter_id:, transaction:)
    case process[:process]
      when :none
        person_transaction_path(person_id: starter_id, id: transaction[:id])
      else
        raise NotImplementedError.new("Not implemented for process #{process}")
    end
  end

  def after_create_actions!(process:, transaction:, community_id:)
    case process[:process]
      when :none
        # TODO Do I really have to do the state transition here?
        # Shouldn't it be handled by the TransactionService
        MarketplaceService::Transaction::Command.transition_to(transaction[:id], "free")

        # TODO: remove references to transaction model
        transaction = Transaction.find(transaction[:id])

        Delayed::Job.enqueue(MessageSentJob.new(transaction.conversation.messages.last.id, community_id))
      else
        raise NotImplementedError.new("Not implemented for process #{process}")
    end
  end

  # Fetch all related data based on the listing_id
  #
  # Returns: Result::Success([listing_id, listing_model, author, process, gateway])
  #
  def fetch_data(listing_id)
    Result.all(
    ->() {
      if listing_id.nil?
        Result::Error.new("No listing ID provided")
      else
        Result::Success.new(listing_id)
      end
    },
    ->(listing_id) {
      # TODO Do not use Models directly. The data should come from the APIs
      Maybe(@current_community.listings.where(id: listing_id).first)
          .map { |listing_model| Result::Success.new(listing_model) }
          .or_else { Result::Error.new("Can not find listing with id #{listing_id}") }
    },
    ->(_, listing_model) {
      # TODO Do not use Models directly. The data should come from the APIs
      Result::Success.new(listing_model.author)
    },
    ->(_, listing_model, *rest) {
      TransactionService::API::Api.processes.get(community_id: @current_community.id, process_id: listing_model.transaction_process_id)
    },
    ->(*) {
      Result::Success.new(MarketplaceService::Community::Query.payment_type(@current_community.id))
    },
    )
  end

  def validate_form(form_params, process)
    if process[:process] == :none && form_params[:message].blank?
      Result::Error.new("Message can not be empty")
    else
      Result::Success.new
    end
  end

  def price_break_down_locals(tx)
    if tx[:payment_process] == :none && tx[:listing_price].cents == 0
      nil
    else
      unit_type = tx[:unit_type].present? ? ListingViewUtils.translate_unit(tx[:unit_type], tx[:unit_tr_key]) : nil
      localized_selector_label = tx[:unit_type].present? ? ListingViewUtils.translate_quantity(tx[:unit_type], tx[:unit_selector_tr_key]) : nil
      booking = !!tx[:booking]
      quantity = tx[:listing_quantity]
      show_subtotal = !!tx[:booking] || quantity.present? && quantity > 1 || tx[:shipping_price].present?
      total_label = (tx[:payment_process] != :preauthorize) ? t("transactions.price") : t("transactions.total")
      service_charge_in_cent = Transaction.find(tx[:id]).service_charge_in_cent || 0

      TransactionViewUtils.price_break_down_locals({
                                                       listing_price: tx[:listing_price],
                                                       localized_unit_type: unit_type,
                                                       localized_selector_label: localized_selector_label,
                                                       booking: booking,
                                                       start_on: booking ? tx[:booking][:start_on] : nil,
                                                       end_on: booking ? tx[:booking][:end_on] : nil,
                                                       duration: booking ? tx[:booking][:duration] : nil,
                                                       quantity: quantity,
                                                       subtotal: show_subtotal ? tx[:listing_price] * quantity : nil,
                                                       total: Maybe(tx[:payment_total]).or_else(tx[:checkout_total]),
                                                       shipping_price: tx[:shipping_price],
                                                       service_charge: service_charge_in_cent / 100,
                                                       total_label: total_label
                                                   })
    end
  end

  def render_free(listing_model:, author_model:, community:, params:)
    # TODO This data should come from API
    listing = {
        id: listing_model.id,
        title: listing_model.title,
        action_button_label: t(listing_model.action_button_tr_key),
    }
    author = {
        display_name: PersonViewUtils.person_display_name(author_model, community),
        username: author_model.username
    }

    unit_type = listing_model.unit_type.present? ? ListingViewUtils.translate_unit(listing_model.unit_type, listing_model.unit_tr_key) : nil
    localized_selector_label = listing_model.unit_type.present? ? ListingViewUtils.translate_quantity(listing_model.unit_type, listing_model.unit_selector_tr_key) : nil
    booking_start = Maybe(params)[:start_on].map { |d| TransactionViewUtils.parse_booking_date(d) }.or_else(nil)
    booking_end = Maybe(params)[:end_on].map { |d| TransactionViewUtils.parse_booking_date(d) }.or_else(nil)
    booking = !!(booking_start && booking_end)
    duration = booking ? DateUtils.duration_days(booking_start, booking_end) : nil
    quantity = Maybe(booking ? DateUtils.duration_days(booking_start, booking_end) : TransactionViewUtils.parse_quantity(params[:quantity])).or_else(1)
    total_label = t("transactions.price")

    m_price_break_down = Maybe(listing_model).select { |listing_model| listing_model.price.present? }.map { |listing_model|
      TransactionViewUtils.price_break_down_locals(
          {
              listing_price: listing_model.price,
              localized_unit_type: unit_type,
              localized_selector_label: localized_selector_label,
              booking: booking,
              start_on: booking_start,
              end_on: booking_end,
              duration: duration,
              quantity: quantity,
              subtotal: quantity != 1 ? listing_model.price * quantity : nil,
              total: listing_model.price * quantity,
              shipping_price: nil,
              total_label: total_label
          })
    }

    render "transactions/new", locals: {
                                 listing: listing,
                                 author: author,
                                 action_button_label: t(listing_model.action_button_tr_key),
                                 m_price_break_down: m_price_break_down,
                                 booking_start: booking_start,
                                 booking_end: booking_end,
                                 quantity: quantity,
                                 form_action: person_transactions_path(person_id: @current_user, listing_id: listing_model.id)
                             }
  end
end
