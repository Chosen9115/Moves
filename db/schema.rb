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

ActiveRecord::Schema[8.1].define(version: 2026_03_11_140000) do
  create_table "app_preferences", force: :cascade do |t|
    t.boolean "ai_enabled", default: false, null: false
    t.string "ai_provider", default: "openai", null: false
    t.datetime "created_at", null: false
    t.string "openai_api_key"
    t.string "openai_model", default: "gpt-4.1-mini", null: false
    t.datetime "updated_at", null: false
  end

  create_table "campaigns", force: :cascade do |t|
    t.integer "active_move_count", default: 0, null: false
    t.decimal "confidence_trend", precision: 8, scale: 4
    t.datetime "created_at", null: false
    t.decimal "momentum_score", precision: 8, scale: 4
    t.string "name", null: false
    t.text "objective"
    t.integer "project_id"
    t.integer "status", default: 0, null: false
    t.decimal "total_ev", precision: 12, scale: 4
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["project_id"], name: "index_campaigns_on_project_id"
    t.index ["status"], name: "index_campaigns_on_status"
    t.index ["uuid"], name: "index_campaigns_on_uuid", unique: true
  end

  create_table "moves", force: :cascade do |t|
    t.integer "adjusted_probability"
    t.json "advantages", default: [], null: false
    t.integer "base_rate"
    t.json "blockers", default: [], null: false
    t.integer "campaign_id"
    t.datetime "completed_at"
    t.decimal "confidence_score", precision: 8, scale: 4
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "due_date"
    t.integer "effort_minutes"
    t.decimal "ev_score", precision: 12, scale: 4
    t.integer "move_type", default: 0, null: false
    t.text "notes"
    t.json "payoff_tags", default: [], null: false
    t.integer "payoff_type"
    t.integer "payoff_value_normalized"
    t.decimal "payoff_value_raw", precision: 12, scale: 2
    t.string "recommendation"
    t.integer "stage", default: 0, null: false
    t.integer "subjective_probability"
    t.text "success_definition"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["campaign_id"], name: "index_moves_on_campaign_id"
    t.index ["payoff_value_normalized"], name: "index_moves_on_payoff_value_normalized"
    t.index ["recommendation"], name: "index_moves_on_recommendation"
    t.index ["stage"], name: "index_moves_on_stage"
    t.index ["uuid"], name: "index_moves_on_uuid", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.integer "cadence", default: 1
    t.string "color", default: "#1E5C42", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "objective"
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.index ["uuid"], name: "index_projects_on_uuid", unique: true
  end

  create_table "signals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "direction", default: 2, null: false
    t.integer "magnitude", default: 1, null: false
    t.integer "move_id", null: false
    t.text "note"
    t.string "signal_type", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["direction"], name: "index_signals_on_direction"
    t.index ["move_id"], name: "index_signals_on_move_id"
    t.index ["uuid"], name: "index_signals_on_uuid", unique: true
  end

  add_foreign_key "campaigns", "projects"
  add_foreign_key "moves", "campaigns"
  add_foreign_key "signals", "moves"
end
