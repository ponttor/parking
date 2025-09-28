# frozen_string_literal: true

class Ticket < ApplicationRecord
  include AasmStateEventConcern

  GRACE_PERIOD = 15.minutes

  validates :issued_at, presence: true
  validates :barcode, presence: true, uniqueness: true, format: { with: /\A[0-9a-f]{16}\z/ }

  scope :occupied, -> { where.not(state: 'used') }

  def valid_until
    return unless paid_at

    paid_at + GRACE_PERIOD
  end

  def payment_grace_expired?
    paid? && paid_at.present? && paid_at < GRACE_PERIOD.ago
  end

  def can_take_payment?
    !paid? || payment_grace_expired?
  end

  def repay!(payment_option)
    update!(paid_at: Time.current, payment_option: payment_option)
  end

  def gate_state(now: Time.current)
    paid? && now <= valid_until ? 'paid' : 'unpaid'
  end

  def self.occupied_count(lock: false)
    rel = occupied
    rel = rel.lock if lock
    rel.count
  end
end
