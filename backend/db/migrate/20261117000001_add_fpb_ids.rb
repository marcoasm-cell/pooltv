# Links players and teams to the Federação Portuguesa de Bilhar (portalbilhar.pt):
# the athlete licence number and the team code (e.g. "EQP7605").
# Re-importing updates the record with the same id instead of adding a copy.
class AddFpbIds < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :fpb_license, :integer
    add_column :players, :fpb_club, :string
    add_index :players, %i[account_id fpb_license], unique: true, where: "fpb_license IS NOT NULL"

    add_column :teams, :fpb_code, :string
    add_column :teams, :fpb_club, :string
    add_index :teams, %i[account_id fpb_code], unique: true, where: "fpb_code IS NOT NULL"
  end
end
