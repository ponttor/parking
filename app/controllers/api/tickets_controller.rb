# frozen_string_literal: true

class Api::TicketsController < ApplicationController
  def show
    ticket = Ticket.find_by!(barcode: params[:barcode])

    render json: ticket, serializer: TicketPriceSerializer, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'ticket not found' }, status: :not_found
  end

  def create
    ticket = TicketService.create

    if ticket.save
      render json: ticket, serializer: TicketSerializer, status: :created
    else
      render json: { errors: ticket.errors.to_hash(true) }, status: :unprocessable_entity
    end
  end

  def payments
    ticket = Ticket.find_by!(barcode: params[:barcode])

    unless ticket.can_take_payment?
      return render json: { error: 'invalid state', state: ticket.state }, status: :unprocessable_entity
    end

    result = process_payment!(ticket, pay_params[:payment_option])

    render json: ticket,
           serializer: TicketPaymentSerializer,
           charged_price: result[:charged_price],
           status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'ticket not found' }, status: :not_found
  end

  private

  def pay_params
    params.require(:payment).permit(:payment_option)
  end

  def process_payment!(ticket, option)
    now    = Time.current
    charge = TicketPriceService.call(ticket, now: now)[:price_eur]

    ticket.payment_grace_expired? ? ticket.repay!(option) : ticket.pay!(option)

    { charged_price: charge }
  end
end
