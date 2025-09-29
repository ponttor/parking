# frozen_string_literal: true

class TicketPriceSerializer < ActiveModel::Serializer
  attributes :barcode, :issued_at, :hours_started, :price

  def issued_at
    object.issued_at.utc.iso8601(0)
  end

  def hours_started
    price_calculation[:hours_started]
  end

  def price
    price_calculation[:price_eur]
  end

  private

  def price_calculation
    @price_calculation ||= TicketPriceService.call(object, instance_options[:now])
  end
end
