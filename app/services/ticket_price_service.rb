# frozen_string_literal: true

class TicketPriceService
  RATE_EUR        = 2
  SECONDS_IN_HOUR = 3600.0

  def self.call(issued_at:)
    seconds = (Time.current - issued_at).to_f
    hours_started = (seconds / SECONDS_IN_HOUR).ceil.clamp(0, Float::INFINITY)
    {
      hours_started: hours_started,
      price_eur: hours_started * RATE_EUR
    }
  end
end
