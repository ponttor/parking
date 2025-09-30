# frozen_string_literal: true

class TicketIssuanceService
  class ParkingFullError < StandardError; end

  def self.call
    ActiveRecord::Base.transaction(requires_new: true) do
      slot = ParkingSlot.free
                        .lock('FOR UPDATE SKIP LOCKED')
                        .first
      raise ParkingFullError, 'no capacity' unless slot

      ticket = Ticket.new(
        barcode: SecureRandom.hex(8),
        issued_at: Time.current
      )
      ticket.save!

      slot.update!(ticket_id: ticket.id)
      ticket
    end
  end
end
