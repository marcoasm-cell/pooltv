module PlayerSerializer
  module_function

  def call(player)
    { id: player.id, name: player.name, nickname: player.nickname, display_name: player.display_name, country_code: player.country_code,
      fpb_license: player.fpb_license, fpb_club: player.fpb_club, photo_url: photo_path(player) }
  end

  # Path on the API of the square photo (the client adds the API host). The link
  # is signed, so overlays can show it without a session.
  def photo_path(player)
    thumb = player.photo_thumb or return
    Rails.application.routes.url_helpers.rails_storage_proxy_path(thumb, only_path: true)
  end
end
