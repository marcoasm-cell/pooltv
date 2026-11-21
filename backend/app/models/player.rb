class Player < ApplicationRecord
  belongs_to :account
  has_many :team_players, dependent: :destroy
  has_many :teams, through: :team_players
  has_many :match_players, dependent: :restrict_with_error
  has_many :entries, dependent: :restrict_with_error
  has_one_attached :photo

  # Square photo for lists and overlays
  def photo_thumb
    photo.variant(resize_to_fill: [ 256, 256, { crop: :attention } ]) if photo.attached?
  end

  validates :name, presence: true

  def display_name
    nickname.presence || name
  end
end
