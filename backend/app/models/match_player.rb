class MatchPlayer < ApplicationRecord
  belongs_to :match
  belongs_to :player

  validates :side, inclusion: { in: Match::SIDES }
end
