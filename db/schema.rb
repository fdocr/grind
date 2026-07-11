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

ActiveRecord::Schema[8.1].define(version: 2026_07_11_060000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "contributions", force: :cascade do |t|
    t.text "admin_reply"
    t.text "comments"
    t.integer "course_id"
    t.datetime "created_at", null: false
    t.datetime "finalized_at"
    t.integer "kind", default: 0, null: false
    t.string "proposed_city"
    t.string "proposed_country"
    t.string "proposed_name"
    t.string "proposed_state_province"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["course_id"], name: "index_contributions_on_course_id"
    t.index ["kind"], name: "index_contributions_on_kind"
    t.index ["status"], name: "index_contributions_on_status"
    t.index ["user_id"], name: "index_contributions_on_user_id"
  end

  create_table "courses", force: :cascade do |t|
    t.string "address"
    t.string "city"
    t.string "country", null: false
    t.datetime "created_at", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.boolean "metric", default: false, null: false
    t.string "name", null: false
    t.string "osm_id"
    t.string "osm_status"
    t.datetime "osm_synced_at"
    t.string "phone"
    t.string "public_id", null: false
    t.string "state_province"
    t.json "tees", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.string "zip"
    t.index ["city"], name: "index_courses_on_city"
    t.index ["country"], name: "index_courses_on_country"
    t.index ["name", "city", "state_province"], name: "index_courses_on_identity", unique: true
    t.index ["name"], name: "index_courses_on_name"
    t.index ["public_id"], name: "index_courses_on_public_id", unique: true
  end

  create_table "deliveries", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "round_id", null: false
    t.integer "score_to_par", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["course_id"], name: "index_deliveries_on_course_id"
    t.index ["round_id"], name: "index_deliveries_on_round_id"
    t.index ["user_id"], name: "index_deliveries_on_user_id"
  end

  create_table "holes", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.json "green_geometry"
    t.json "green_input"
    t.string "green_source"
    t.integer "handicap", null: false
    t.integer "number", null: false
    t.integer "par", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "number"], name: "index_holes_on_course_id_and_number", unique: true
    t.index ["course_id"], name: "index_holes_on_course_id"
  end

  create_table "rounds", force: :cascade do |t|
    t.integer "botched_up_downs", default: 0, null: false
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.json "hole_scores", default: {}, null: false
    t.integer "inside_pw_9i", default: 0, null: false
    t.integer "oop_tee_shots", default: 0, null: false
    t.datetime "started_at"
    t.string "tee"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["course_id"], name: "index_rounds_on_course_id"
    t.index ["token"], name: "index_rounds_on_token", unique: true
    t.index ["user_id"], name: "index_rounds_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "contributions", "courses"
  add_foreign_key "contributions", "users"
  add_foreign_key "deliveries", "courses"
  add_foreign_key "deliveries", "rounds"
  add_foreign_key "deliveries", "users"
  add_foreign_key "holes", "courses"
  add_foreign_key "rounds", "courses"
  add_foreign_key "rounds", "users"
  add_foreign_key "sessions", "users"
end
