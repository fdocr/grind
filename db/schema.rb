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

ActiveRecord::Schema[8.1].define(version: 2026_06_21_144000) do
  create_table "courses", force: :cascade do |t|
    t.string "address"
    t.string "city"
    t.string "country", null: false
    t.datetime "created_at", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.boolean "metric", default: false, null: false
    t.string "name", null: false
    t.string "phone"
    t.string "state_province"
    t.json "tees", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.string "zip"
    t.index ["city"], name: "index_courses_on_city"
    t.index ["country"], name: "index_courses_on_country"
    t.index ["name", "city", "state_province"], name: "index_courses_on_identity", unique: true
    t.index ["name"], name: "index_courses_on_name"
  end

  create_table "deliveries", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "round_id", null: false
    t.integer "score_to_par", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_deliveries_on_course_id"
    t.index ["round_id"], name: "index_deliveries_on_round_id"
  end

  create_table "holes", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
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
    t.integer "three_putts", default: 0, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_rounds_on_course_id"
    t.index ["token"], name: "index_rounds_on_token", unique: true
  end

  add_foreign_key "deliveries", "courses"
  add_foreign_key "deliveries", "rounds"
  add_foreign_key "holes", "courses"
  add_foreign_key "rounds", "courses"
end
