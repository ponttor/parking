# frozen_string_literal: true

class ParkingSlot < ApplicationRecord
  belongs_to :ticket, optional: true

  scope :free,  -> { where(ticket_id: nil) }
  scope :taken, -> { where.not(ticket_id: nil) }
end
