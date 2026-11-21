# A sponsor whose logo rotates in the header of the OBS overlays
class Sponsor < ApplicationRecord
  include HasLogo

  belongs_to :account

  validates :name, presence: true

  scope :ordered, -> { order(:position, :id) }
end
