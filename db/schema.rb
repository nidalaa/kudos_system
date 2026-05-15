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

ActiveRecord::Schema[8.0].define(version: 2026_05_15_171404) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "employees", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name"
    t.string "username", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["username"], name: "index_employees_on_username", unique: true
  end

  create_table "kudos", force: :cascade do |t|
    t.bigint "giver_id", null: false
    t.bigint "receiver_id", null: false
    t.string "reactions_from", default: [], array: true
    t.text "reason"
    t.string "category"
    t.text "original_message"
    t.string "slack_message_id", null: false
    t.string "slack_channel"
    t.datetime "slack_timestamp"
    t.string "status", default: "pending_review", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["giver_id"], name: "index_kudos_on_giver_id"
    t.index ["receiver_id"], name: "index_kudos_on_receiver_id"
    t.index ["slack_message_id"], name: "index_kudos_on_slack_message_id", unique: true
    t.index ["status"], name: "index_kudos_on_status"
  end

  add_foreign_key "kudos", "employees", column: "giver_id"
  add_foreign_key "kudos", "employees", column: "receiver_id"
end
