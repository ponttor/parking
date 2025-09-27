# frozen_string_literal: true

class Api::TicketsController < ApplicationController
  def create
    ticket = TicketService.create

    if ticket.save
      render json: ticket, serializer: TicketSerializer, status: :created
    else
      render json: { errors: ticket.errors.to_hash(true) }, status: :unprocessable_entity
    end
  end
end
