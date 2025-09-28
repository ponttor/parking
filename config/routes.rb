# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    resources :tickets, only: %i[create show], param: :barcode do
      member { post :payments }
    end
  end
end
