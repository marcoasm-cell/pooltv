class PoolTable < ApplicationRecord
  belongs_to :account
  belongs_to :current_match, class_name: "Match", optional: true
  has_many :matches, dependent: :nullify

  has_secure_token :overlay_token, length: 32

  validates :name, presence: true

  after_commit :broadcast, on: %i[create update]

  def overlay_config
    account.overlay_config.merge(overlay_settings || {})
  end

  # Matches waiting to be played on this table, in order
  def queue
    matches.where(status: "scheduled").order(:queue_position, :id)
  end

  def broadcast_stream
    "table:#{id}"
  end

  def broadcast
    Broadcaster.table(self)
  end
end
