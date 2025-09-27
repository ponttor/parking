# frozen_string_literal: true

module TicketService
  def self.create
    Ticket.new(
      barcode: SecureRandom.hex(8),
      issued_at: Time.current
    )
  end
end
