class CreateParkingSlots < ActiveRecord::Migration[7.2]
  def change
    create_table :parking_slots do |t|
      t.references :ticket, foreign_key: { on_delete: :nullify }, index: false
      t.timestamps null: false
    end

    add_index :parking_slots, :ticket_id,
              where: 'ticket_id IS NULL',
              name:  'index_parking_slots_on_ticket_id_free'

    add_index :parking_slots, :ticket_id,
              unique: true,
              where: 'ticket_id IS NOT NULL',
              name:  'index_parking_slots_on_ticket_id_taken_unique'
  end
end
