# Downloads athletes' photos from the FPB portal after an import
class FpbPhotosJob < ApplicationJob
  queue_as :default

  # pairs: [[player_id, file], ...]
  def perform(pairs)
    Fpb::Importer.download_photos(pairs)
  end
end
