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

ActiveRecord::Schema[7.0].define(version: 2022_12_03_235224) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "churches", force: :cascade do |t|
    t.string "name"
    t.date "fundation_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "movements", force: :cascade do |t|
    t.integer "kind_of"
    t.decimal "amount", precision: 8, scale: 2
    t.date "payment_date"
    t.text "description"
    t.bigint "user_id"
    t.bigint "wallet_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_movements_on_user_id"
    t.index ["wallet_id"], name: "index_movements_on_wallet_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.integer "gender"
    t.string "contact_number"
    t.string "address"
    t.date "baptism_date"
    t.date "member_since"
    t.integer "marital_status"
    t.string "cpf"
    t.string "rg"
    t.date "birth_date"
    t.bigint "church_id", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.index ["church_id"], name: "index_users_on_church_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "wallets", force: :cascade do |t|
    t.string "icon"
    t.string "name"
    t.integer "kind_of"
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_wallets_on_church_id"
  end

  add_foreign_key "movements", "users"
  add_foreign_key "movements", "wallets"
  add_foreign_key "users", "churches"
  add_foreign_key "wallets", "churches"
end
