# frozen_string_literal: true

require 'test_helper'

class TicketIssuanceServiceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def setup
    ParkingSlot.update_all(ticket_id: nil)
    Ticket.delete_all

    ensure_slots(5)
  end

  def teardown
    ParkingSlot.update_all(ticket_id: nil)
    Ticket.delete_all
  end

  test 'does not exceed capacity under heavy concurrency' do
    pool_size  = ActiveRecord::Base.connection_pool.size
    attempts   = pool_size * 2
    start_gate = Queue.new

    threads = Array.new(attempts) do
      Thread.new do
        start_gate.pop
        begin
          TicketIssuanceService.call
        rescue TicketIssuanceService::ParkingFullError
          nil
        end
      end
    end

    attempts.times { start_gate << :go }
    threads.each(&:join)

    assert_operator Ticket.count, :<=, 5
    assert_operator ParkingSlot.where.not(ticket_id: nil).count, :<=, 5
  end

  private

  def ensure_slots(capacity)
    have    = ParkingSlot.count
    missing = capacity - have
    if missing.positive?
      now   = Time.current
      rows  = Array.new(missing) { { created_at: now, updated_at: now } }
      ParkingSlot.insert_all!(rows)
    elsif missing.negative?
      ParkingSlot.where(ticket_id: nil).limit(-missing).delete_all
    end
  end
end
