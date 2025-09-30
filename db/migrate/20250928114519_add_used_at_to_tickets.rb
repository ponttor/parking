class AddUsedAtToTickets < ActiveRecord::Migration[7.2]
  def change
    add_column :tickets, :used_at, :datetime, null: true

    add_index :tickets, :used_at
  end
end
