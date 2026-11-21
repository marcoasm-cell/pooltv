# Tables a tournament plays on: its matches are dealt to them automatically
class AddPoolTableIdsToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :pool_table_ids, :jsonb, default: [], null: false
  end
end
