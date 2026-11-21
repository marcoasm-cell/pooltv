# Optional name of a match outside any tournament, shown on the overlay
class AddNameToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :name, :string
  end
end
