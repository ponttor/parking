# frozen_string_literal: true

class Api::TicketsController < ApplicationController
  def show
    render json: ticket,
           serializer: TicketPriceSerializer,
           now: Time.current,
           status: :ok
  end

  def create
    ticket = TicketIssuanceService.call

    render json: ticket,
           serializer: TicketSerializer,
           status: :created
  end

  def payments
    unless ticket.can_take_payment?
      return render json: { error: 'invalid state', state: ticket.state }, status: :unprocessable_entity
    end

    now = Time.current
    option = pay_params[:payment_option]
    price = TicketPriceService.call(ticket, now)[:price_eur]

    Ticket.transaction do
      ticket.lock!

      ticket.payment_grace_expired?(now) ? ticket.repay!(option) : ticket.pay!(option)

      render json: ticket,
             serializer: TicketPaymentSerializer,
             charged_price: price,
             status: :ok
    end
  end

  def state
    render json: { state: ticket.gate_state(now: Time.current) }, status: :ok
  end

  def use
    ticket = Ticket.find_by!(barcode: params[:barcode])

    return render json: ticket, serializer: TicketUseSerializer, status: :ok if ticket.used?
    return render json: { error: 'invalid state', state: ticket.state }, status: :unprocessable_entity unless ticket.paid?
    return render json: { error: 'grace expired', state: ticket.state }, status: :unprocessable_entity if Time.current > ticket.valid_until

    Ticket.transaction do
      ticket.lock!
      ticket.use!

      render json: ticket, serializer: TicketUseSerializer, status: :ok
    end
  end

  private

  def pay_params
    params.require(:payment).permit(:payment_option)
  end

  def ticket
    @ticket ||= Ticket.find_by!(barcode: params[:barcode])
  end
end
