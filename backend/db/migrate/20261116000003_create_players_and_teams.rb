class CreatePlayersAndTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :nickname
      t.string :country_code
      t.timestamps
    end

    create_table :teams do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :short_name
      t.string :color
      t.timestamps
    end

    create_table :team_players do |t|
      t.references :team, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.boolean :captain, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :team_players, %i[team_id player_id], unique: true
  end
end
