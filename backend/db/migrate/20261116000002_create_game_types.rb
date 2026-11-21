class CreateGameTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :game_types do |t|
      # nil = built-in game type available to every account
      t.references :account, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      # "racks": race to N racks; "points": first to N points (straight pool)
      t.string :scoring_mode, null: false, default: "racks"
      t.integer :default_target, null: false, default: 5
      # who breaks the next rack: alternate / winner / loser
      t.string :break_rule, null: false, default: "alternate"
      t.string :rules_url
      t.timestamps
    end
    add_index :game_types, %i[account_id key], unique: true, nulls_not_distinct: true
  end
end
