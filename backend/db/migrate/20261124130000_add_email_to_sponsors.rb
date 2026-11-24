# A contact email for each sponsor, kept for the club only (not on the overlays)
class AddEmailToSponsors < ActiveRecord::Migration[8.1]
  def change
    add_column :sponsors, :email, :string
  end
end
