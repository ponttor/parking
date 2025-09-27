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
end
