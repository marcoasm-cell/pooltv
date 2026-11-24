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

ActiveRecord::Schema[8.1].define(version: 2026_11_24_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "overlay_token", null: false
    t.jsonb "overlay_settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["overlay_token"], name: "index_accounts_on_overlay_token", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.bigint "player_id"
    t.bigint "team_id"
    t.integer "seed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "lineup", default: {}, null: false
    t.index ["player_id"], name: "index_entries_on_player_id"
    t.index ["team_id"], name: "index_entries_on_team_id"
    t.index ["tournament_id", "player_id"], name: "index_entries_on_tournament_id_and_player_id", unique: true, where: "(player_id IS NOT NULL)"
    t.index ["tournament_id", "team_id"], name: "index_entries_on_tournament_id_and_team_id", unique: true, where: "(team_id IS NOT NULL)"
    t.index ["tournament_id"], name: "index_entries_on_tournament_id"
  end

  create_table "fixtures", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.string "bracket", default: "winners", null: false
    t.integer "round", null: false
    t.integer "position", null: false
    t.bigint "home_entry_id"
    t.bigint "away_entry_id"
    t.boolean "home_bye", default: false, null: false
    t.boolean "away_bye", default: false, null: false
    t.bigint "winner_entry_id"
    t.integer "home_score", default: 0, null: false
    t.integer "away_score", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.bigint "winner_to_id"
    t.string "winner_to_slot"
    t.bigint "loser_to_id"
    t.string "loser_to_slot"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["away_entry_id"], name: "index_fixtures_on_away_entry_id"
    t.index ["home_entry_id"], name: "index_fixtures_on_home_entry_id"
    t.index ["loser_to_id"], name: "index_fixtures_on_loser_to_id"
    t.index ["tournament_id", "bracket", "round", "position"], name: "idx_on_tournament_id_bracket_round_position_e962575675", unique: true
    t.index ["tournament_id"], name: "index_fixtures_on_tournament_id"
    t.index ["winner_entry_id"], name: "index_fixtures_on_winner_entry_id"
    t.index ["winner_to_id"], name: "index_fixtures_on_winner_to_id"
  end

  create_table "game_types", force: :cascade do |t|
    t.bigint "account_id"
    t.string "key", null: false
    t.string "name", null: false
    t.string "scoring_mode", default: "racks", null: false
    t.integer "default_target", default: 5, null: false
    t.string "break_rule", default: "alternate", null: false
    t.string "rules_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "key"], name: "index_game_types_on_account_id_and_key", unique: true, nulls_not_distinct: true
    t.index ["account_id"], name: "index_game_types_on_account_id"
  end

  create_table "match_events", force: :cascade do |t|
    t.bigint "match_id", null: false
    t.bigint "user_id"
    t.string "side", null: false
    t.integer "points", default: 1, null: false
    t.string "breaking_side_before"
    t.datetime "undone_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_match_events_on_match_id"
    t.index ["user_id"], name: "index_match_events_on_user_id"
  end

  create_table "match_players", force: :cascade do |t|
    t.bigint "match_id", null: false
    t.bigint "player_id", null: false
    t.string "side", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id", "player_id"], name: "index_match_players_on_match_id_and_player_id", unique: true
    t.index ["match_id"], name: "index_match_players_on_match_id"
    t.index ["player_id"], name: "index_match_players_on_player_id"
  end

  create_table "matches", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "fixture_id"
    t.bigint "game_type_id", null: false
    t.bigint "pool_table_id"
    t.integer "rubber_number"
    t.string "kind", default: "singles", null: false
    t.integer "target", null: false
    t.integer "home_score", default: 0, null: false
    t.integer "away_score", default: 0, null: false
    t.string "breaking_side"
    t.string "winner_side"
    t.string "status", default: "scheduled", null: false
    t.integer "queue_position"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "public_token", null: false
    t.index ["account_id"], name: "index_matches_on_account_id"
    t.index ["fixture_id"], name: "index_matches_on_fixture_id"
    t.index ["game_type_id"], name: "index_matches_on_game_type_id"
    t.index ["pool_table_id"], name: "index_matches_on_pool_table_id"
    t.index ["public_token"], name: "index_matches_on_public_token", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "nickname"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "fpb_license"
    t.string "fpb_club"
    t.string "fpb_photo"
    t.index ["account_id", "fpb_license"], name: "index_players_on_account_id_and_fpb_license", unique: true, where: "(fpb_license IS NOT NULL)"
    t.index ["account_id"], name: "index_players_on_account_id"
  end

  create_table "pool_tables", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.string "overlay_token", null: false
    t.jsonb "overlay_settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "current_match_id"
    t.index ["account_id"], name: "index_pool_tables_on_account_id"
    t.index ["current_match_id"], name: "index_pool_tables_on_current_match_id"
    t.index ["overlay_token"], name: "index_pool_tables_on_overlay_token", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.string "user_agent"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id"
    t.index ["account_id"], name: "index_sessions_on_account_id"
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sponsors", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_sponsors_on_account_id"
  end

  create_table "team_players", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "player_id", null: false
    t.boolean "captain", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_team_players_on_player_id"
    t.index ["team_id", "player_id"], name: "index_team_players_on_team_id_and_player_id", unique: true
    t.index ["team_id"], name: "index_team_players_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "fpb_code"
    t.string "fpb_club"
    t.index ["account_id", "fpb_code"], name: "index_teams_on_account_id_and_fpb_code", unique: true, where: "(fpb_code IS NOT NULL)"
    t.index ["account_id"], name: "index_teams_on_account_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "game_type_id", null: false
    t.string "name", null: false
    t.string "kind", default: "individual", null: false
    t.string "format", default: "single_elimination", null: false
    t.integer "target", null: false
    t.boolean "grand_final_reset", default: true, null: false
    t.string "status", default: "draft", null: false
    t.date "starts_on"
    t.jsonb "team_match_format", default: [], null: false
    t.string "team_win_condition", default: "rubbers", null: false
    t.integer "team_target"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "ended_early", default: false, null: false
    t.jsonb "pool_table_ids", default: [], null: false
    t.string "public_token", null: false
    t.datetime "archived_at"
    t.index ["account_id"], name: "index_tournaments_on_account_id"
    t.index ["game_type_id"], name: "index_tournaments_on_game_type_id"
    t.index ["public_token"], name: "index_tournaments_on_public_token", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "scorer", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "entries", "players"
  add_foreign_key "entries", "teams"
  add_foreign_key "entries", "tournaments"
  add_foreign_key "fixtures", "entries", column: "away_entry_id"
  add_foreign_key "fixtures", "entries", column: "home_entry_id"
  add_foreign_key "fixtures", "entries", column: "winner_entry_id"
  add_foreign_key "fixtures", "fixtures", column: "loser_to_id"
  add_foreign_key "fixtures", "fixtures", column: "winner_to_id"
  add_foreign_key "fixtures", "tournaments"
  add_foreign_key "game_types", "accounts"
  add_foreign_key "match_events", "matches"
  add_foreign_key "match_events", "users"
  add_foreign_key "match_players", "matches"
  add_foreign_key "match_players", "players"
  add_foreign_key "matches", "accounts"
  add_foreign_key "matches", "fixtures"
  add_foreign_key "matches", "game_types"
  add_foreign_key "matches", "pool_tables"
  add_foreign_key "players", "accounts"
  add_foreign_key "pool_tables", "accounts"
  add_foreign_key "pool_tables", "matches", column: "current_match_id"
  add_foreign_key "sessions", "accounts", on_delete: :nullify
  add_foreign_key "sessions", "users"
  add_foreign_key "sponsors", "accounts"
  add_foreign_key "team_players", "players"
  add_foreign_key "team_players", "teams"
  add_foreign_key "teams", "accounts"
  add_foreign_key "tournaments", "accounts"
  add_foreign_key "tournaments", "game_types"
  add_foreign_key "users", "accounts"
end
