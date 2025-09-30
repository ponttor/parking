# frozen_string_literal: true

class TicketPriceService
  RATE_EUR        = 2
  SECONDS_IN_HOUR = 3600.0
  class << self
    def call(ticket, now)
      return { hours_started: 0, price_eur: 0 } if ticket.paid? && now <= ticket.valid_until

      start_time = ticket.paid? ? ticket.paid_at : ticket.issued_at
      hours_started = hours_between(start_time, now)

      { hours_started:, price_eur: hours_started * RATE_EUR }
    end

    private

    def hours_between(start_time, end_time)
      seconds = (end_time - start_time).to_f
      (seconds / SECONDS_IN_HOUR).ceil.clamp(0, Float::INFINITY)
    end
  end
end
