# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 0) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "blocks", id: :serial, force: :cascade do |t|
    t.integer "height", null: false
    t.text "blockhash", null: false
    t.boolean "started", default: false
    t.boolean "ended", default: false
    t.index ["blockhash"], name: "blocks_blockhash_key", unique: true
    t.index ["height"], name: "blocks_block_index"
    t.index ["height"], name: "blocks_block_key", unique: true
  end

  create_table "invalid_transactions", id: :serial, force: :cascade do |t|
    t.text "transaction_id", null: false
    t.index ["transaction_id"], name: "invalid_transactions_transaction_id_key", unique: true
  end

  create_table "payments", id: :integer, default: -> { "nextval('addresses_id_seq'::regclass)" }, force: :cascade do |t|
    t.text "address"
    t.text "txid"
    t.decimal "debit"
    t.decimal "credit"
    t.text "blockhash"
    t.integer "n"
    t.index ["address", "txid", "debit", "credit", "blockhash", "n"], name: "addresses_address_txid_debit_credit_blockhash_n_key", unique: true
    t.index ["address"], name: "addresses_address_index"
    t.index ["blockhash"], name: "addresses_blockhash_index"
  end

end
