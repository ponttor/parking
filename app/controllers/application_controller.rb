# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ApiErrorHandling

  allow_browser versions: :modern
  skip_forgery_protection
end
