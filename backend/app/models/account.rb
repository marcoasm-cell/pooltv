class Account < ApplicationRecord
  OVERLAY_DEFAULTS = {
    # What a table overlay shows with no match: "hidden" or "waiting"
    "idle_mode" => "hidden",
    # Seconds the winner banner stays up after a match ends
    "winner_banner_seconds" => 15,
    # Layout of the all-tables overlay: "split" (one camera window per table),
    # "grid", "sidebar" or "ticker"
    "all_tables_layout" => "split",
    # Show the Pool TV badge in the header of the overlays (next to the club's logo)
    "show_pool_tv_logo" => true,
    # Seconds each sponsor stays in the header before the next one
    "sponsor_seconds" => 8,
    # QR code to the public page of the match or tournament on the overlays
    "show_qr" => true
  }.freeze

  include HasLogo

  has_many :users, dependent: :destroy
  # Admins' sessions looking at this account go back to their own one
  has_many :visiting_sessions, class_name: "Session", dependent: :nullify
  has_many :pool_tables, -> { order(:position, :id) }, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :teams, dependent: :destroy
  has_many :tournaments, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :custom_game_types, class_name: "GameType", dependent: :destroy
  has_many :sponsors, dependent: :destroy

  has_secure_token :overlay_token, length: 32

  validates :name, presence: true

  def game_types
    GameType.where(account_id: [ nil, id ]).order(:name)
  end

  def overlay_config
    OVERLAY_DEFAULTS.merge(overlay_settings || {})
  end

  def broadcast_stream
    "account:#{id}"
  end
end
