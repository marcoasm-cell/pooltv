class CreateTournaments < ActiveRecord::Migration[8.1]
  def change
    create_table :tournaments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :game_type, null: false, foreign_key: true
      t.string :name, null: false
      # "individual": players play players; "team": teams play teams
      t.string :kind, null: false, default: "individual"
      # single_elimination / double_elimination / round_robin / friendly
      t.string :format, null: false, default: "single_elimination"
      # race-to racks (or points) of every individual match
      t.integer :target, null: false
      t.boolean :grand_final_reset, null: false, default: true
      t.string :status, null: false, default: "draft"
      t.date :starts_on
      # Team tournaments: the rubbers of each team match, e.g. ["singles", "doubles"]
      t.jsonb :team_match_format, null: false, default: []
      # rubbers: most rubbers won; racks: most racks over all rubbers
      t.string :team_win_condition, null: false, default: "rubbers"
      # rubbers: stop as soon as a team reaches this many rubbers (nil = play all)
      t.integer :team_target
      t.timestamps
    end

    # A player or a team taking part in a tournament
    create_table :entries do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :player, foreign_key: true
      t.references :team, foreign_key: true
      t.integer :seed
      t.timestamps
    end
    add_index :entries, %i[tournament_id player_id], unique: true, where: "player_id IS NOT NULL"
    add_index :entries, %i[tournament_id team_id], unique: true, where: "team_id IS NOT NULL"
  end
end
