# A logo image for the OBS overlays (club or sponsor), shown at most 600x200
module HasLogo
  extend ActiveSupport::Concern

  TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_BYTES = 5.megabytes

  included do
    has_one_attached :logo
  end

  # Attaches an uploaded file, after checking it is an image we can show
  def attach_logo!(upload)
    valid = upload.respond_to?(:content_type) && TYPES.include?(upload.content_type) && upload.size <= MAX_BYTES
    raise ArgumentError, I18n.t("app_errors.bad_image") unless valid

    logo.attach(upload)
  end

  # Path on the API of the resized logo (the client adds the API host). The link
  # is signed, so overlays can show it without a session.
  def logo_path
    return unless logo.attached?

    Rails.application.routes.url_helpers.rails_storage_proxy_path(logo.variant(resize_to_limit: [ 600, 200 ]), only_path: true)
  end
end
