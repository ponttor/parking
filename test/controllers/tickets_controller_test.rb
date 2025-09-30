# frozen_string_literal: true

require 'test_helper'

class ApiTicketsCreateTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def test_creates_ticket_and_returns_json
    freeze_time do
      post '/api/tickets', as: :json
      assert_response :created

      body = response.parsed_body
      assert_equal %w[barcode issued_at].sort, body.keys.sort
      assert_match(/\A[0-9a-f]{16}\z/, body['barcode'])
      assert_equal Time.current.iso8601, body['issued_at']
      assert Ticket.exists?(barcode: body['barcode'])
    end
  end

  def test_returns_422_when_service_returns_invalid_ticket
    Ticket.new
    invalid_barcode = 'z' * 16

    SecureRandom.stub(:hex, ->(_n) { invalid_barcode }) do
      post '/api/tickets', as: :json
    end

    assert_response :unprocessable_entity

    body = response.parsed_body
    assert body['errors'].is_a?(Hash)
    assert_includes body['errors'].keys, 'barcode'
  end

  def test_returns_422_on_duplicate_barcode
    existing = Ticket.create!(barcode: 'deadbeefdeadbeef', issued_at: Time.current)
    Ticket.new(barcode: existing.barcode, issued_at: Time.current)

    SecureRandom.stub(:hex, ->(_n) { existing.barcode }) do
      post '/api/tickets', as: :json
    end

    assert_response :unprocessable_entity

    body = response.parsed_body
    assert body['errors'].is_a?(Hash)
    assert_includes body['errors'].keys, 'barcode'
  end

  def test_returns_price_for_ticket
    freeze_time do
      issued_at = 70.minutes.ago
      ticket = Ticket.create!(barcode: 'deadbeefdeadbeef', issued_at: issued_at)

      get "/api/tickets/#{ticket.barcode}", as: :json
      assert_response :ok

      body = response.parsed_body
      assert_equal ticket.barcode, body['barcode']
      assert_equal issued_at.utc.iso8601(0), body['issued_at']
      assert_equal TicketPriceService::RATE_EUR, body['hours_started']
      assert_equal TicketPriceService::RATE_EUR * 2, body['price']
    end
  end

  def test_one_hour_exact_is_counted_as_one_hour
    freeze_time do
      issued_at = 1.hour.ago
      ticket = Ticket.create!(barcode: 'cafebabecafebabe', issued_at: issued_at)

      get "/api/tickets/#{ticket.barcode}", as: :json
      assert_response :ok

      body = response.parsed_body
      assert_equal 1, body['hours_started']
      assert_equal TicketPriceService::RATE_EUR, body['price']
    end
  end

  def test_returns_404_when_ticket_not_found
    get '/api/tickets/notexists', as: :json
    assert_response :not_found

    body = response.parsed_body
    assert_equal 'ticket not found', body['error']
  end

  def test_pay_unpaid_success
    freeze_time do
      t = issue_ticket
      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'card' } }, as: :json

      assert_response :ok
      body = response.parsed_body

      assert_equal t.barcode, body['barcode']
      assert_equal 'paid', body['state']
      assert_equal 'card', body['payment_option']
      assert_equal TicketPriceService::RATE_EUR * 2, body['price']

      expect_paid_at = Time.current.utc.iso8601(0)
      expect_valid   = (Time.current + Ticket::GRACE_PERIOD).utc.iso8601(0)

      assert_equal expect_paid_at, body['paid_at']
      assert_equal expect_valid, body['valid_until']
    end
  end

  def test_pay_twice_is_invalid_state
    freeze_time do
      t = issue_ticket
      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'cash' } }, as: :json
      assert_response :ok

      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'cash' } }, as: :json
      assert_response :unprocessable_entity

      body = response.parsed_body
      assert_equal 'invalid state', body['error']
      assert_equal 'paid', body['state']
    end
  end

  def test_pay_not_found
    post '/api/tickets/notexists/payments', params: { payment: { payment_option: 'card' } }, as: :json
    assert_response :not_found

    body = response.parsed_body
    assert_equal 'ticket not found', body['error']
  end

  def test_repay_after_grace_period_success
    freeze_time do
      t = issue_ticket
      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'cash' } }, as: :json
      assert_response :ok

      Time.current

      travel Ticket::GRACE_PERIOD + 1.minute

      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'card' } }, as: :json
      assert_response :ok

      body = response.parsed_body

      assert_equal t.barcode, body['barcode']
      assert_equal 'paid', body['state']
      assert_equal 'card', body['payment_option']

      expect_paid_at = Time.current.utc.iso8601(0)
      expect_valid   = (Time.current + Ticket::GRACE_PERIOD).utc.iso8601(0)
      assert_equal expect_paid_at, body['paid_at']
      assert_equal expect_valid,   body['valid_until']

      assert_equal TicketPriceService::RATE_EUR * 1, body['price']
    end
  end

  def test_repay_within_grace_period_is_invalid_state
    freeze_time do
      t = issue_ticket
      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'cash' } }, as: :json
      assert_response :ok

      travel 10.minutes

      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'cash' } }, as: :json
      assert_response :unprocessable_entity

      body = response.parsed_body
      assert_equal 'invalid state', body['error']
      assert_equal 'paid', body['state']
    end
  end

  def test_unpaid_ticket_returns_unpaid
    freeze_time do
      t = Ticket.create!(barcode: 'aaaaaaaaaaaaaaaa', issued_at: 10.minutes.ago)
      get "/api/tickets/#{t.barcode}/state", as: :json
      assert_response :ok
      assert_equal 'unpaid', response.parsed_body['state']
    end
  end

  def test_paid_within_15_minutes_returns_paid
    freeze_time do
      t = Ticket.create!(barcode: 'bbbbbbbbbbbbbbbb', issued_at: 70.minutes.ago)
      # оплатили сейчас
      post "/api/tickets/#{t.barcode}/payments",
           params: { payment: { payment_option: 'card' } }, as: :json
      assert_response :ok

      travel 10.minutes
      get "/api/tickets/#{t.barcode}/state", as: :json
      assert_response :ok
      assert_equal 'paid', response.parsed_body['state']
    end
  end

  def test_paid_after_15_minutes_returns_unpaid
    freeze_time do
      t = Ticket.create!(barcode: 'cccccccccccccccc', issued_at: 70.minutes.ago)
      post "/api/tickets/#{t.barcode}/payments",
           params: { payment: { payment_option: 'cash' } }, as: :json
      assert_response :ok

      travel Ticket::GRACE_PERIOD + 1.minute
      get "/api/tickets/#{t.barcode}/state", as: :json
      assert_response :ok
      assert_equal 'unpaid', response.parsed_body['state']
    end
  end

  def test_state_not_found
    get '/api/tickets/notexists/state', as: :json
    assert_response :not_found
    assert_equal 'ticket not found', response.parsed_body['error']
  end

  def test_use_success_within_grace
    freeze_time do
      t = issue
      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'card' } }, as: :json
      assert_response :ok

      travel 10.minutes
      post "/api/tickets/#{t.barcode}/use", as: :json
      assert_response :ok

      body = response.parsed_body
      assert_equal 'used', body['state']
      assert_equal Time.current.utc.iso8601(0), body['used_at']
    end
  end

  def test_use_unpaid_invalid
    freeze_time do
      t = issue
      post "/api/tickets/#{t.barcode}/use", as: :json
      assert_response :unprocessable_entity
      assert_equal 'invalid state', response.parsed_body['error']
    end
  end

  def test_use_grace_expired_invalid
    freeze_time do
      t = issue
      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'card' } }, as: :json
      assert_response :ok

      travel Ticket::GRACE_PERIOD + 1.minute
      post "/api/tickets/#{t.barcode}/use", as: :json
      assert_response :unprocessable_entity
      assert_equal 'grace expired', response.parsed_body['error']
    end
  end

  def test_use_idempotent
    freeze_time do
      t = issue
      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'card' } }, as: :json
      assert_response :ok

      post "/api/tickets/#{t.barcode}/use", as: :json
      assert_response :ok
      first = response.parsed_body['used_at']

      post "/api/tickets/#{t.barcode}/use", as: :json
      assert_response :ok
      second = response.parsed_body['used_at']

      assert_equal first, second
    end
  end

  def test_use_not_found
    post '/api/tickets/notexists/use', as: :json
    assert_response :not_found
    assert_equal 'ticket not found', response.parsed_body['error']
  end

  def test_used_ticket_does_not_count_as_occupied
    freeze_time do
      t = issue(barcode: 'eeeeeeeeeeeeeeee', issued_at: 30.minutes.ago)

      post "/api/tickets/#{t.barcode}/payments",
           params: { payment: { payment_option: 'card' } }, as: :json
      assert_response :ok

      post "/api/tickets/#{t.barcode}/use", as: :json
      assert_response :ok

      get '/api/free-spaces', as: :json
      assert_response :ok
      body = response.parsed_body

      assert_equal 0, body['occupied']
      assert_equal ParkingSlot.count, body['free_spots']
      assert_equal ParkingSlot.count, body['capacity']
      assert body['as_of'].is_a?(String)
    end
  end

  def test_cannot_issue_when_parking_full
    with_temp_capacity(1) do
      freeze_time do
        post '/api/tickets', as: :json
        assert_response :created

        post '/api/tickets', as: :json
        assert_response :unprocessable_entity
        body = response.parsed_body
        assert_equal 'parking full', body['error']
      end
    end
  end

  def test_can_issue_again_after_use_when_was_full
    with_temp_capacity(1) do
      freeze_time do
        post '/api/tickets', as: :json
        assert_response :created
        barcode = response.parsed_body['barcode']

        post "/api/tickets/#{barcode}/payments",
             params: { payment: { payment_option: 'card' } }, as: :json
        assert_response :ok

        post "/api/tickets/#{barcode}/use", as: :json
        assert_response :ok
        assert_equal 'used', response.parsed_body['state']

        post '/api/tickets', as: :json
        assert_response :created
      end
    end
  end

  def test_issue_assigns_exactly_one_slot
    freeze_time do
      post '/api/tickets', as: :json
      assert_response :created
      barcode = response.parsed_body['barcode']
      ticket  = Ticket.find_by!(barcode:)

      assert_equal 1, ParkingSlot.where(ticket_id: ticket.id).count
    end
  end

  def test_invalid_use_does_not_free_slot
    with_temp_capacity(1) do
      freeze_time do
        post '/api/tickets', as: :json
        ticket = Ticket.find_by!(barcode: response.parsed_body['barcode'])

        post "/api/tickets/#{ticket.barcode}/payments",
             params: { payment: { payment_option: 'card' } }, as: :json
        assert_response :ok
        assert_equal 1, ParkingSlot.where(ticket_id: ticket.id).count

        travel Ticket::GRACE_PERIOD + 1.minute
        post "/api/tickets/#{ticket.barcode}/use", as: :json
        assert_response :unprocessable_entity
        assert_equal 1, ParkingSlot.where(ticket_id: ticket.id).count

        # слот занят → новый билет выдать нельзя
        post '/api/tickets', as: :json
        assert_response :unprocessable_entity
      end
    end
  end

  def test_successful_use_frees_slot_and_allows_new_issue
    with_temp_capacity(1) do
      freeze_time do
        post '/api/tickets', as: :json
        ticket = Ticket.find_by!(barcode: response.parsed_body['barcode'])

        post "/api/tickets/#{ticket.barcode}/payments",
             params: { payment: { payment_option: 'card' } }, as: :json
        assert_response :ok

        post "/api/tickets/#{ticket.barcode}/use", as: :json
        assert_response :ok
        assert_equal 0, ParkingSlot.where(ticket_id: ticket.id).count

        post '/api/tickets', as: :json
        assert_response :created
      end
    end
  end

  def test_concurrent_use_is_idempotent_and_frees_slot_once
    freeze_time do
      post '/api/tickets', as: :json
      t = Ticket.find_by!(barcode: response.parsed_body['barcode'])

      post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'card' } }, as: :json
      assert_response :ok

      start_gate = Queue.new
      threads = Array.new(2) do
        Thread.new do
          start_gate.pop
          post "/api/tickets/#{t.barcode}/use", as: :json
        end
      end
      2.times { start_gate << :go }
      threads.each(&:join)

      post "/api/tickets/#{t.barcode}/use", as: :json
      assert_response :ok
      assert_equal 'used', response.parsed_body['state']

      assert_equal 0, ParkingSlot.where(ticket_id: t.id).count
    end
  end

  def test_concurrent_payment_allows_only_one_success
    freeze_time do
      post '/api/tickets', as: :json
      t = Ticket.find_by!(barcode: response.parsed_body['barcode'])

      start_gate = Queue.new
      statuses   = Queue.new
      threads = Array.new(2) do
        Thread.new do
          start_gate.pop
          post "/api/tickets/#{t.barcode}/payments", params: { payment: { payment_option: 'card' } }, as: :json
          statuses << response.status
        end
      end
      2.times { start_gate << :go }
      threads.each(&:join)

      s1, s2 = Array.new(2) { statuses.pop }
      assert_includes [[200, 422], [422, 200], [200, 200]], [s1, s2].sort

      get "/api/tickets/#{t.barcode}/state", as: :json
      assert_response :ok
      assert_equal 'paid', response.parsed_body['state']

      assert_equal 1, ParkingSlot.where(ticket_id: t.id).count
    end
  end

  def test_free_spaces_matches_slots_counts
    freeze_time do
      ParkingSlot.update_all(ticket_id: nil)
      ensure_slots(ParkingSlot.count)

      post '/api/tickets', as: :json
      post '/api/tickets', as: :json

      get '/api/free-spaces', as: :json
      body = response.parsed_body

      capacity = ParkingSlot.count
      occupied = ParkingSlot.where.not(ticket_id: nil).count

      assert_equal capacity, body['capacity']
      assert_equal occupied, body['occupied']
      assert_equal capacity - occupied, body['free_spots']
    end
  end

  test 'unique partial index prevents assigning one ticket to multiple slots' do
    ticket = Ticket.new(
      barcode: SecureRandom.base58(12),
      state: 'unpaid',
      issued_at: Time.current
    )
    ticket.save!(validate: false)

    s1 = ParkingSlot.create!
    s2 = ParkingSlot.create!

    s1.update!(ticket_id: ticket.id)

    assert_raises(ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid) do
      s2.update_column(:ticket_id, ticket.id)
    end

    assert_equal [s1.id], ParkingSlot.where(ticket_id: ticket.id).pluck(:id)
  end

  private

  def issue_ticket(barcode: 'deadbeefdeadbeef', issued_at: 65.minutes.ago)
    Ticket.create!(barcode:, issued_at:)
  end

  def issue(barcode: 'abcdabcdabcdabcd', issued_at: 70.minutes.ago)
    Ticket.create!(barcode:, issued_at:)
  end

  def with_temp_capacity(temp_capacity)
    original_slots = ParkingSlot.count

    ensure_slots(temp_capacity)
    begin
      yield
    ensure
      ensure_slots(original_slots)
    end
  end

  def ensure_slots(capacity)
    have    = ParkingSlot.count
    missing = capacity - have

    if missing.positive?
      now   = Time.current
      rows  = Array.new(missing) { { created_at: now, updated_at: now } }
      ParkingSlot.insert_all!(rows)
    elsif missing.negative?

      ids = ParkingSlot.where(ticket_id: nil).order(:id).limit(-missing).pluck(:id)
      ParkingSlot.where(id: ids).delete_all
    end
  end
end
