class SeedInitialParkingSlots < ActiveRecord::Migration[7.2]
  CAPACITY = 54

  def up
    count = select_value("SELECT COUNT(*) FROM parking_slots").to_i
    return if count > 0

    now = Time.current.utc.to_s
    values = Array.new(CAPACITY) { "('#{now}', '#{now}')" }.join(",")
    execute "INSERT INTO parking_slots (created_at, updated_at) VALUES #{values}"
  end
end
