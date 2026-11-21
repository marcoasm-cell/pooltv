class MatchEvent < ApplicationRecord
  belongs_to :match
  belongs_to :user, optional: true

  scope :active, -> { where(undone_at: nil) }
end
