# frozen_string_literal: true

class Ticket < ApplicationRecord
  validates :barcode, presence: true, uniqueness: true, format: { with: /\A[0-9a-f]{16}\z/ }
  validates :issued_at, presence: true
end
