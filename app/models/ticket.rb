# frozen_string_literal: true

class Ticket < ApplicationRecord
  include AasmStateEventConcern

  GRACE_PERIOD = 15.minutes

  has_one :parking_slot, dependent: :nullify

  validates :issued_at, presence: true
  validates :barcode, presence: true, uniqueness: true, format: { with: /\A[0-9a-f]{16}\z/ }

  after_commit :release_slot_if_used, on: :update

  def valid_until
    return unless paid_at

    paid_at + GRACE_PERIOD
  end

  def payment_grace_expired?(now)
    paid? && paid_at.present? && paid_at < now - GRACE_PERIOD
  end

  def can_take_payment?
    !paid? || payment_grace_expired?(Time.current)
  end

  def repay!(payment_option)
    update!(paid_at: Time.current, payment_option: payment_option)
  end

  def gate_state(now: Time.current)
    paid? && now <= valid_until ? 'paid' : 'unpaid'
  end

  private

  def release_slot_if_used
    return unless saved_change_to_state? && used?

    if (slot = ParkingSlot.find_by(ticket_id: id))
      slot.update!(ticket_id: nil)
    end
  end
end
