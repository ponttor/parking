class AddPaymentAndStateToTickets < ActiveRecord::Migration[7.2]
  def change
    add_column :tickets, :state, :string, null: false, default: 'unpaid'
    add_column :tickets, :paid_at, :datetime
    add_column :tickets, :payment_option, :string

    add_index :tickets, :state
    add_index :tickets, :paid_at
  end
end
