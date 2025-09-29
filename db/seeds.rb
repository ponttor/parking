# frozen_string_literal: true

capacity = Integer(ENV.fetch('PARKING_CAPACITY', Parking::CAPACITY))
have     = ParkingSlot.count
missing  = capacity - have

if missing.positive?
  now = Time.current
  ParkingSlot.insert_all!(Array.new(missing) { { created_at: now, updated_at: now } })
elsif missing.negative?
  ParkingSlot.free.limit(-missing).delete_all
end
