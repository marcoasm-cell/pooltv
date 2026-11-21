# Lineup of a team in a standalone team match:
#   { "starters" => [ids by position], "reserves" => [ids], "slots" => [ids playing each position now] }
class AddLineupToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :lineup, :jsonb, default: {}, null: false
  end
end
