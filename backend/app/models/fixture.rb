# One node of a tournament: entry vs entry. Individual tournaments play one
# match per fixture; team tournaments play one match per rubber and the
# fixture is the team match.
class Fixture < ApplicationRecord
  SLOTS = %w[home away].freeze
  BRACKETS = %w[winners losers grand_final group].freeze
  STATUSES = %w[pending ready live finished void].freeze

  belongs_to :tournament
  belongs_to :home_entry, class_name: "Entry", optional: true
  belongs_to :away_entry, class_name: "Entry", optional: true
  belongs_to :winner_entry, class_name: "Entry", optional: true
  belongs_to :winner_to, class_name: "Fixture", optional: true
  belongs_to :loser_to, class_name: "Fixture", optional: true
  has_many :matches, -> { order(:rubber_number, :id) }, dependent: :destroy

  validates :bracket, inclusion: { in: BRACKETS }
  validates :status, inclusion: { in: STATUSES }

  after_commit :broadcast

  def entry(slot) = public_send("#{slot}_entry")
  def bye?(slot) = public_send("#{slot}_bye")

  def loser_entry
    return unless status == "finished" && winner_entry

    winner_entry == home_entry ? away_entry : home_entry
  end

  def place!(slot, entry)
    update!("#{slot}_entry" => entry, "#{slot}_bye" => false)
    resolve!
  end

  def mark_bye!(slot)
    update!("#{slot}_entry" => nil, "#{slot}_bye" => true)
    resolve!
  end

  # Moves a pending fixture on once both slots are known: plays it, gives a
  # walkover against a bye, or voids it when both slots are byes.
  def resolve!
    return unless status == "pending"

    if home_entry && away_entry
      update!(status: "ready")
      create_matches!
    elsif home_bye && away_bye
      update!(status: "void")
      advance!(nil, nil)
    elsif (home_entry && away_bye) || (away_entry && home_bye)
      finish_with!(home_entry ? "home" : "away")
    end
  end

  def match_started!
    update!(status: "live") if status == "ready"
  end

  def match_finished!
    return if status == "finished"

    recompute_scores!
    if tournament.team?
      decide_team_match!
    else
      finish_with!(matches.first.winner_side)
    end
  end

  # A finished match is being reopened by an undo: take back whatever its
  # result moved forward, as long as the next fixtures have not started.
  def reopen_for!(match)
    if status == "finished"
      unadvance!
      update!(status: "live", winner_entry: nil)
      create_matches! if tournament.team?
      tournament.update!(status: "running") if tournament.status == "finished"
    end
    recompute_scores!
  end

  # Team match tied in an elimination round: play another rubber
  def add_rubber!(kind = "singles")
    raise Errors::InvalidState, I18n.t("app_errors.only_team_rubbers") unless tournament.team?
    raise Errors::InvalidState, I18n.t("app_errors.fixture_status", status: I18n.t("fixture_statuses.#{status}")) unless status.in?(%w[ready live])

    match = matches.create!(
      account: tournament.account, game_type: tournament.game_type, target: tournament.target,
      kind:, rubber_number: matches.maximum(:rubber_number).to_i + 1
    )
    tournament.auto_assign!(match)
    match
  end

  # Standalone team match: puts a bench player in a lineup position for every
  # game of that position not started yet. Reserves may go into any position;
  # a starter taken off may only come back into the position they started in.
  def substitute!(side, slot, player_id)
    raise ArgumentError, I18n.t("app_errors.unknown_side", side:) unless side.in?(SLOTS)
    raise Errors::InvalidState, I18n.t("app_errors.fixture_status", status: I18n.t("fixture_statuses.#{status}")) unless status.in?(%w[ready live])

    entry = entry(side)
    lineup = entry&.lineup.presence
    raise Errors::InvalidState, I18n.t("app_errors.no_lineup") unless lineup

    starters, reserves, slots = lineup.values_at("starters", "reserves", "slots")
    slot = Integer(slot, exception: false)
    raise Errors::InvalidState, I18n.t("app_errors.unknown_position") unless slot && slot >= 0 && slot < slots.size

    player_id = player_id.to_i
    raise Errors::InvalidState, I18n.t("app_errors.already_in_position", position: slots.index(player_id) + 1) if slots.include?(player_id)
    if starters.include?(player_id)
      own = starters.index(player_id)
      raise Errors::InvalidState, I18n.t("app_errors.return_own_position", position: own + 1) if own != slot
    elsif !reserves.include?(player_id)
      raise Errors::InvalidState, I18n.t("app_errors.not_a_reserve", team: entry.display_name)
    end

    transaction do
      slots = slots.dup
      slots[slot] = player_id
      entry.update!(lineup: lineup.merge("slots" => slots))

      pairings = TeamMatchBuilder.pairings(slots.size)
      position = side == "home" ? 0 : 1
      matches.select(&:scheduled?).each do |m|
        pairing = pairings[m.rubber_number.to_i - 1]
        next unless pairing && pairing[position] == slot

        lineup_ids = SLOTS.to_h { |s| [ s.to_sym, m.side_players(s).map(&:id) ] }
        lineup_ids[side.to_sym] = [ player_id ]
        m.set_lineup!(**lineup_ids)
      end
    end
    touch # broadcast the new lineup
  end

  # Decides the fixture without playing, e.g. a no-show
  def walkover!(winner_side)
    raise ArgumentError, I18n.t("app_errors.unknown_side", side: winner_side) unless winner_side.in?(SLOTS)
    raise Errors::InvalidState, I18n.t("app_errors.fixture_status", status: I18n.t("fixture_statuses.#{status}")) unless status.in?(%w[ready live])
    raise Errors::InvalidState, I18n.t("app_errors.fixture_match_live") if matches.any?(&:live?)

    transaction do
      drop_unplayed_matches!
      finish_with!(winner_side)
    end
  end

  private

  def create_matches!
    rubbers = tournament.team? ? tournament.team_match_format : [ "singles" ]
    existing = matches.pluck(:rubber_number)
    rubbers.each_with_index do |kind, i|
      next if existing.include?(i + 1)

      match = matches.create!(
        account: tournament.account, game_type: tournament.game_type, target: tournament.target,
        kind:, rubber_number: i + 1
      )
      tournament.auto_assign!(match)
      next if tournament.team?

      match.match_players.create!(player: home_entry.player, side: "home")
      match.match_players.create!(player: away_entry.player, side: "away")
    end
    matches.reset
  end

  def recompute_scores!
    played = matches.reload.select(&:finished?)
    if !tournament.team? || tournament.team_win_condition == "racks"
      update!(home_score: played.sum(&:home_score), away_score: played.sum(&:away_score))
    else
      update!(home_score: played.count { |m| m.winner_side == "home" },
              away_score: played.count { |m| m.winner_side == "away" })
    end
  end

  def decide_team_match!
    leader = home_score > away_score ? "home" : "away"
    clinch = tournament.team_win_condition == "rubbers" && tournament.team_target

    if clinch && [ home_score, away_score ].max >= clinch
      drop_unplayed_matches!
      finish_with!(leader)
    elsif matches.all?(&:finished?)
      if home_score != away_score
        finish_with!(leader)
      elsif tournament.draws_allowed?
        finish_with!(nil)
      end
      # Tied in an elimination round: stays live until a decider is added
    end
  end

  # Rubbers nobody started are not needed once the team match is decided
  def drop_unplayed_matches!
    matches.select { |m| m.scheduled? && m.match_events.empty? }.each(&:destroy!)
    matches.reset
  end

  def finish_with!(winner_side)
    winner = winner_side && entry(winner_side)
    loser = winner_side && entry(Match.other_side(winner_side))
    update!(status: "finished", winner_entry: winner)
    advance!(winner, loser)
  end

  def advance!(winner, loser)
    if bracket == "grand_final" && round == 1
      advance_grand_final!(winner)
    else
      send_to(winner_to, winner_to_slot, winner)
      send_to(loser_to, loser_to_slot, loser)
    end
    tournament.check_finished!
  end

  # The losers-bracket champion has to beat the undefeated winners-bracket
  # champion twice, so a home win ends it and an away win forces the reset.
  def advance_grand_final!(winner)
    reset = tournament.fixtures.find_by(bracket: "grand_final", round: 2)
    return unless reset

    if winner == home_entry
      reset.update!(status: "void")
    else
      reset.update!(home_entry:, away_entry:, home_bye: false, away_bye: false)
      reset.resolve!
    end
  end

  def send_to(target, slot, entry)
    return unless target

    entry ? target.place!(slot, entry) : target.mark_bye!(slot)
  end

  def unadvance!
    targets = if bracket == "grand_final" && round == 1
      reset = tournament.fixtures.find_by(bracket: "grand_final", round: 2)
      reset ? [ [ reset, "home" ], [ reset, "away" ] ] : []
    else
      [ [ winner_to, winner_to_slot ], [ loser_to, loser_to_slot ] ].select(&:first)
    end

    targets.map(&:first).uniq.each do |target|
      next if target.status == "void" && bracket == "grand_final"
      next if target.status == "pending"

      started = target.status.in?(%w[live finished void]) || target.matches.any? { |m| !m.scheduled? }
      raise Errors::InvalidState, I18n.t("app_errors.next_fixture_started") if started
    end

    targets.each do |target, slot|
      target.matches.each(&:destroy!)
      target.update!("#{slot}_entry" => nil, "#{slot}_bye" => false, status: "pending")
    end
  end

  def broadcast
    Broadcaster.fixture(self)
  end
end
