# frozen_string_literal: true

require 'test_helper'

class ApiTicketsCreateTest < ActionDispatch::IntegrationTest
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
end
