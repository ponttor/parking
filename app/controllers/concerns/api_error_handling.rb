# app/controllers/concerns/api_error_handling.rb
# frozen_string_literal: true

module ApiErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound,            with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid,             with: :render_unprocessable
    rescue_from TicketIssuanceService::ParkingFullError, with: :render_parking_full

    rescue_from AASM::InvalidTransition, with: :render_invalid_transition if defined?(AASM)
  end

  private

  def render_not_found(_error)
    render json: { error: 'ticket not found' }, status: :not_found
  end

  def render_unprocessable(error)
    render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
  end

  def render_parking_full(_error)
    render json: { error: 'parking full' }, status: :unprocessable_entity
  end

  def render_invalid_transition(error)
    render json: { error: 'invalid state', details: error.message }, status: :unprocessable_entity
  end
end
