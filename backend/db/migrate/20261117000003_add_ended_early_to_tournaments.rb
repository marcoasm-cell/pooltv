# A tournament stopped by an admin before every fixture was played
class AddEndedEarlyToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :ended_early, :boolean, default: false, null: false
  end
end
