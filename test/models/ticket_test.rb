# frozen_string_literal: true

require 'test_helper'

class TicketTest < ActiveSupport::TestCase
  def test_valid_ticket
    t = Ticket.new(barcode: 'a1b2c3d4e5f6a7b8', issued_at: Time.current)
    assert t.valid?
  end

  def test_barcode_presence
    t = Ticket.new(issued_at: Time.current)
    assert_not t.valid?
    assert_includes t.errors[:barcode], "can't be blank"
  end

  def test_barcode_format
    t = Ticket.new(barcode: 'XYZ', issued_at: Time.current)
    assert_not t.valid?
    assert_includes t.errors[:barcode], 'is invalid'
  end

  def test_barcode_uniqueness
    Ticket.create!(barcode: 'a1b2c3d4e5f6a7b8', issued_at: Time.current)
    dup = Ticket.new(barcode: 'a1b2c3d4e5f6a7b8', issued_at: Time.current)
    assert_not dup.valid?
    assert_includes dup.errors[:barcode], 'has already been taken'
  end

  def test_issued_at_presence
    t = Ticket.new(barcode: 'a1b2c3d4e5f6a7b8')
    assert_not t.valid?
    assert_includes t.errors[:issued_at], "can't be blank"
  end
end
