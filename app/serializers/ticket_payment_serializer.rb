# frozen_string_literal: true

class TicketPaymentSerializer < ActiveModel::Serializer
  attributes :barcode, :paid_at, :valid_until, :price, :payment_option, :state

  def paid_at
    object.paid_at.utc.iso8601(0)
  end

  def valid_until
    object.valid_until.utc.iso8601(0)
  end

  def price
    instance_options[:charged_price]
  end
end
