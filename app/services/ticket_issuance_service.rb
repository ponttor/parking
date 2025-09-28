# frozen_string_literal: true

class TicketIssuanceService
  class ParkingFullError < StandardError; end

  class << self
    def call
      Ticket.transaction do
        occupied = Ticket.occupied.lock.count
        capacity = Parking::CAPACITY
        raise ParkingFullError if occupied >= capacity

        ticket = TicketService.create
        ticket.save!

        ticket
      end
    end
  end
end
