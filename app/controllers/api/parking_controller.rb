# frozen_string_literal: true

class Api::ParkingController < ApplicationController
  def free_spaces
    snapshot = ParkingOccupancyService.snapshot(Time.current)
    render json: snapshot, status: :ok
  end
end
