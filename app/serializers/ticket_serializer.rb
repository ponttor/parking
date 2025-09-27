# frozen_string_literal: true

class TicketSerializer < ActiveModel::Serializer
  attributes :barcode, :issued_at

  def issued_at
    object.issued_at.utc.iso8601(0)
  end
end
