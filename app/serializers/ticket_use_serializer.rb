# frozen_string_literal: true

class TicketUseSerializer < ActiveModel::Serializer
  attributes :barcode, :state, :paid_at, :used_at

  def paid_at     = object.paid_at.utc.iso8601(0)
  def used_at     = object.used_at.utc.iso8601(0)
end
