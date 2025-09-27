class CreateTickets < ActiveRecord::Migration[7.2]
  def change
    create_table :tickets do |t|
      t.string   :barcode, null: false, limit: 16
      t.datetime :issued_at, null: false
      t.timestamps
    end

    add_index :tickets, :barcode, unique: true
  end
end
