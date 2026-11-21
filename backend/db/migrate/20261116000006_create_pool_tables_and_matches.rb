class CreatePoolTablesAndMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :pool_tables do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      # Secret key of this table's OBS overlay link
      t.string :overlay_token, null: false, index: { unique: true }
      t.jsonb :overlay_settings, null: false, default: {}
      t.timestamps
    end

    # A single game played on one table: a tournament match, a rubber of a
    # team match or a quick match outside any tournament.
    create_table :matches do |t|
      t.references :account, null: false, foreign_key: true
      t.references :fixture, foreign_key: true
      t.references :game_type, null: false, foreign_key: true
      t.references :pool_table, foreign_key: true
      t.integer :rubber_number
      # singles / doubles
      t.string :kind, null: false, default: "singles"
      t.integer :target, null: false
      t.integer :home_score, null: false, default: 0
      t.integer :away_score, null: false, default: 0
      # home / away; nil until the lag decides it
      t.string :breaking_side
      t.string :winner_side
      # scheduled / live / finished
      t.string :status, null: false, default: "scheduled"
      t.integer :queue_position
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    create_table :match_players do |t|
      t.references :match, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.string :side, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :match_players, %i[match_id player_id], unique: true

    # Every score change, kept so it can be undone and audited
    create_table :match_events do |t|
      t.references :match, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :side, null: false
      t.integer :points, null: false, default: 1
      t.string :breaking_side_before
      t.datetime :undone_at
      t.timestamps
    end

    add_reference :pool_tables, :current_match, foreign_key: { to_table: :matches }
  end
end
