# A sponsor whose logo rotates in the header of the OBS overlays
class Sponsor < ApplicationRecord
  include HasLogo

  belongs_to :account

  normalizes :email, with: ->(e) { e.strip.downcase.presence }

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true

  scope :ordered, -> { order(:position, :id) }
end
