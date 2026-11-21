# Teams are shown by their full name and the home/away colours
class RemoveShortNameAndColorFromTeams < ActiveRecord::Migration[8.1]
  def change
    remove_column :teams, :short_name, :string
    remove_column :teams, :color, :string
  end
end
