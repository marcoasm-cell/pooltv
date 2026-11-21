# A player (individual tournaments) or a team (team tournaments) taking part
class Entry < ApplicationRecord
  belongs_to :tournament
  belongs_to :player, optional: true
  belongs_to :team, optional: true

  validate :participant_matches_kind
  validate :not_entered_twice

  def display_name
    (team || player)&.display_name
  end

  def full_name
    team&.name || player&.name
  end

  private

  # Also kept by a unique index; this gives a readable error, e.g. on a double click
  def not_entered_twice
    others = Entry.where(tournament_id:).where.not(id:)
    errors.add(:player, :already_entered) if player_id && others.exists?(player_id:)
    errors.add(:team, :already_entered) if team_id && others.exists?(team_id:)
  end

  def participant_matches_kind
    if tournament&.team?
      errors.add(:team, :required_entry) if team.nil? || player.present?
      errors.add(:team, :other_account) if team && team.account_id != tournament.account_id
    else
      errors.add(:player, :required_entry) if player.nil? || team.present?
      errors.add(:player, :other_account) if player && player.account_id != tournament.account_id
    end
  end
end
