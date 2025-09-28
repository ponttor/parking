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
    invalid = Ticket.new

    TicketService.stub(:create, invalid) do
      post '/api/tickets', as: :json
    end

    assert_response :unprocessable_entity

    body = response.parsed_body
    assert body['errors'].is_a?(Hash)
    assert_includes body['errors'].keys, 'barcode'
    assert_includes body['errors'].keys, 'issued_at'
  end

  def test_returns_422_on_duplicate_barcode
    existing = Ticket.create!(barcode: 'deadbeefdeadbeef', issued_at: Time.current)

    duplicate = Ticket.new(barcode: existing.barcode, issued_at: Time.current)

    TicketService.stub(:create, duplicate) do
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

  def issue_ticket(barcode: 'deadbeefdeadbeef', issued_at: 65.minutes.ago)
    Ticket.create!(barcode:, issued_at:)
  end
end
