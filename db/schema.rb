# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_09_29_104404) do
  create_table "parking_slots", force: :cascade do |t|
    t.integer "ticket_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket_id"], name: "index_parking_slots_on_ticket_id_free", where: "ticket_id IS NULL"
    t.index ["ticket_id"], name: "index_parking_slots_on_ticket_id_taken_unique", unique: true, where: "ticket_id IS NOT NULL"
  end

  create_table "tickets", force: :cascade do |t|
    t.string "barcode", limit: 16, null: false
    t.datetime "issued_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "unpaid", null: false
    t.datetime "paid_at"
    t.string "payment_option"
    t.datetime "used_at"
    t.index ["barcode"], name: "index_tickets_on_barcode", unique: true
    t.index ["paid_at"], name: "index_tickets_on_paid_at"
    t.index ["state"], name: "index_tickets_on_state"
    t.index ["used_at"], name: "index_tickets_on_used_at"
  end

  add_foreign_key "parking_slots", "tickets", on_delete: :nullify
end
