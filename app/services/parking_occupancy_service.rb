# frozen_string_literal: true

class ParkingOccupancyService
  class << self
    def snapshot(now: Time.current)
      capacity = ::Parking::CAPACITY
      occupied = Ticket.occupied_count

      free     = [capacity - occupied, 0].max

      { capacity: capacity, occupied: occupied, free_spots: free, as_of: now.utc.iso8601(0) }
    end
  end
end
