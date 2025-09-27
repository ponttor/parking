# frozen_string_literal: true

class Api::TicketsController < ApplicationController
  def show
    ticket = Ticket.find_by!(barcode: params[:id])
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
end
