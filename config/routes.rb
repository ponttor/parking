# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    resources :tickets, only: %i[show create]
  end
end
