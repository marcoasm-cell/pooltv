# A fixture is one node of a tournament: entry vs entry. For individual
# tournaments it holds one match; for team tournaments it is the team match
# and holds one match per rubber.
class CreateFixtures < ActiveRecord::Migration[8.1]
  def change
    create_table :fixtures do |t|
      t.references :tournament, null: false, foreign_key: true
      # winners / losers / grand_final / group
      t.string :bracket, null: false, default: "winners"
      t.integer :round, null: false
      t.integer :position, null: false
      t.references :home_entry, foreign_key: { to_table: :entries }
      t.references :away_entry, foreign_key: { to_table: :entries }
      # A slot that will never be filled (bye in the draw)
      t.boolean :home_bye, null: false, default: false
      t.boolean :away_bye, null: false, default: false
      t.references :winner_entry, foreign_key: { to_table: :entries }
      t.integer :home_score, null: false, default: 0
      t.integer :away_score, null: false, default: 0
      # pending / ready / live / finished / void
      t.string :status, null: false, default: "pending"
      t.references :winner_to, foreign_key: { to_table: :fixtures }
      t.string :winner_to_slot
      t.references :loser_to, foreign_key: { to_table: :fixtures }
      t.string :loser_to_slot
      t.timestamps
    end
    add_index :fixtures, %i[tournament_id bracket round position], unique: true
  end
end
