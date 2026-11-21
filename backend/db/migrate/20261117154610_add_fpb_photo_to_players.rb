# File name of the athlete's photo on the FPB portal, so a re-import downloads
# the photo again only when it changed
class AddFpbPhotoToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :fpb_photo, :string
  end
end
