# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    resources :tickets, only: %i[create show], param: :barcode do
      member do
        post :payments
        get  :state
        post :use
      end
    end
    get 'free-spaces', to: 'parking#free_spaces'
  end
end
