# frozen_string_literal: true

module AasmStateEventConcern
  extend ActiveSupport::Concern

  included do
    include AASM

    aasm column: :state do
      state :unpaid, initial: true
      state :paid
      state :used

      event :pay do
        transitions from: :unpaid, to: :paid,
                    after: ->(payment_option) { after_pay(payment_option) }
      end

      event :use do
        transitions from: :paid, to: :used,
                    guard: :within_grace?,
                    after: :after_use
      end
    end
  end

  private

  def after_pay(payment_option)
    self.payment_option = payment_option.presence || 'unknown'
    self.paid_at        = Time.current
  end

  def within_grace?
    paid_at.present? && Time.current <= valid_until
  end

  def after_use
    self.used_at = Time.current
  end
end
