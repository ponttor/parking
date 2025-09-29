# frozen_string_literal: true

class ParkingOccupancyService
  class << self
    def snapshot(now)
      capacity = ::Parking::CAPACITY
      occupied = ParkingSlot.taken.count
      free     = [capacity - occupied, 0].max
      { capacity:, occupied:, free_spots: free, as_of: now.utc.iso8601(0) }
    end
  end
end
