# Archived tournaments leave the list of tournaments (they can be shown and
# brought back); their results and public page stay as they were.
class AddArchivedAtToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :archived_at, :datetime
  end
end
