# One game played on one table. Either a tournament match (fixture with one
# match), a rubber of a team match (fixture with several matches) or a
# match outside any tournament.
class Match < ApplicationRecord
  SIDES = %w[home away].freeze
  KINDS = %w[singles doubles].freeze
  STATUSES = %w[scheduled live finished].freeze

  belongs_to :account
  belongs_to :fixture, optional: true
  belongs_to :game_type
  belongs_to :pool_table, optional: true
  has_many :match_players, -> { order(:position, :id) }, dependent: :destroy
  has_many :players, through: :match_players
  has_many :match_events, -> { order(:id) }, dependent: :destroy

  # Everything MatchSerializer reads, so serializing many matches costs a
  # handful of queries instead of a few per match
  # (SIDES_PRELOAD is enough with fixture: false)
  SIDES_PRELOAD = [ :game_type, { match_players: { player: { photo_attachment: :blob } } } ].freeze
  SERIALIZER_PRELOAD = [
    *SIDES_PRELOAD,
    # Only what the serializer always reads: this also runs on the caller's
    # objects (from after_commit), and an association loaded here that the
    # caller reads later would be stale (e.g. fixture.matches, which the
    # serializer only counts, or tournament.fixtures, read for some brackets)
    { fixture: [ :tournament, { home_entry: %i[team player] }, { away_entry: %i[team player] } ] }
  ].freeze

  def self.preload_for_serializer(matches, associations = SERIALIZER_PRELOAD)
    ActiveRecord::Associations::Preloader.new(records: matches.compact, associations:).call
    matches
  end

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :target, numericality: { greater_than: 0 }
  validates :breaking_side, :winner_side, inclusion: { in: SIDES }, allow_nil: true
  validate :pool_table_same_account

  after_commit :broadcast

  def self.other_side(side)
    side == "home" ? "away" : "home"
  end

  def tournament
    fixture&.tournament
  end

  def scheduled? = status == "scheduled"
  def live? = status == "live"
  def finished? = status == "finished"

  def points_mode?
    game_type.points?
  end

  def side_players(side)
    match_players.select { |mp| mp.side == side }.map(&:player)
  end

  def players_per_side
    kind == "doubles" ? 2 : 1
  end

  # Name shown for a side: the players, or the fixture entry while the lineup
  # of a team rubber is still unknown.
  def side_name(side)
    names = side_players(side).map(&:display_name)
    return names.join(" / ") if names.any?

    entry = fixture&.public_send("#{side}_entry")
    # Broadcast to every viewer, so in the default language
    tbd = I18n.t("match.tbd", locale: I18n.default_locale)
    tournament&.team? ? tbd : (entry&.display_name || tbd)
  end

  def score(side)
    side == "home" ? home_score : away_score
  end

  # Replaces the players of both sides: { home: [ids], away: [ids] }
  def set_lineup!(home:, away:)
    raise Errors::InvalidState, I18n.t("app_errors.lineup_before_start") unless scheduled?

    transaction do
      match_players.destroy_all
      { "home" => home, "away" => away }.each do |side, ids|
        ids = Array(ids).map(&:to_i)
        raise Errors::InvalidState, I18n.t("app_errors.players_per_side", kind: I18n.t("kinds.#{kind}"), count: players_per_side) if ids.size > players_per_side

        allowed = lineup_pool(side)
        ids.each_with_index do |pid, i|
          player = allowed.find { |p| p.id == pid }
          raise Errors::InvalidState, I18n.t("app_errors.player_cannot_play", player: pid, side: I18n.t("sides.#{side}")) unless player

          match_players.create!(player:, side:, position: i)
        end
      end
    end
    match_players.reset
    self
  end

  # Puts the match in a table's queue (nil removes it from any table)
  def assign_to!(table)
    raise Errors::InvalidState, I18n.t("app_errors.match_finished") if finished?
    raise Errors::InvalidState, I18n.t("app_errors.live_match_table") if live? && table != pool_table

    previous = pool_table
    transaction do
      update!(pool_table: table, queue_position: table && (table.queue.maximum(:queue_position).to_i + 1))
      previous&.update!(current_match: nil) if previous && previous != table && previous.current_match_id == id
    end
  end

  def start!(table: pool_table, breaking_side: self.breaking_side)
    raise Errors::InvalidState, I18n.t("app_errors.match_status", status: I18n.t("match_statuses.#{status}")) unless scheduled?
    raise Errors::InvalidState, I18n.t("app_errors.match_needs_table") unless table
    raise Errors::InvalidState, I18n.t("app_errors.sides_need_players") unless lineup_complete?
    if fixture && fixture.status != "ready" && fixture.status != "live"
      raise Errors::InvalidState, I18n.t("app_errors.fixture_not_ready")
    end
    if table.current_match&.live? && table.current_match != self
      raise Errors::InvalidState, I18n.t("app_errors.table_already_playing", table: table.name)
    end
    if (busy = busy_player)
      raise Errors::InvalidState, I18n.t("app_errors.player_busy", player: busy.player.display_name, table: busy.match.pool_table&.name || I18n.t("app_errors.another_table"))
    end

    transaction do
      update!(pool_table: table, status: "live", started_at: Time.current, queue_position: nil, breaking_side:)
      table.update!(current_match: self)
      fixture&.match_started!
    end
  end

  # Adds a rack (racks mode) or points (points mode, may be negative for
  # fouls) to a side, finishing the match when the target is reached.
  def score!(side, points: 1, user: nil)
    raise Errors::InvalidState, I18n.t("app_errors.match_not_live") unless live?
    raise ArgumentError, I18n.t("app_errors.unknown_side", side:) unless side.in?(SIDES)

    points = points.to_i
    points = 1 unless points_mode?
    raise ArgumentError, I18n.t("app_errors.zero_points") if points.zero?

    transaction do
      lock!
      match_events.create!(side:, points:, user:, breaking_side_before: breaking_side)
      self["#{side}_score"] += points
      self.breaking_side = next_breaker(side) unless points_mode?
      save!
      finish!(side) if score(side) >= target
    end
    self
  end

  # Reverts the last score change, reopening the match if it had ended
  def undo!
    raise Errors::InvalidState, I18n.t("app_errors.nothing_to_undo") unless live? || finished?
    raise Errors::InvalidState, I18n.t("app_errors.tournament_ended") if tournament&.ended_early

    transaction do
      lock!
      event = match_events.active.last
      raise Errors::InvalidState, I18n.t("app_errors.nothing_to_undo") unless event

      reopen! if finished?
      self["#{event.side}_score"] -= event.points
      self.breaking_side = event.breaking_side_before
      event.update!(undone_at: Time.current)
      save!
    end
    self
  end

  # Ends the match. Also used for concessions and referee decisions.
  def finish!(winner_side)
    raise Errors::InvalidState, I18n.t("app_errors.match_not_live") unless live?
    raise ArgumentError, I18n.t("app_errors.unknown_side", side: winner_side) unless winner_side.in?(SIDES)

    transaction do
      update!(status: "finished", winner_side:, finished_at: Time.current)
      fixture&.match_finished!
    end
  end

  private

  def reopen!
    update!(status: "live", winner_side: nil, finished_at: nil)
    fixture&.reopen_for!(self)
    pool_table&.update!(current_match: self) if pool_table && pool_table.current_match_id != id && !pool_table.current_match&.live?
  end

  def next_breaker(rack_winner)
    case game_type.break_rule
    when "winner" then rack_winner
    when "loser" then Match.other_side(rack_winner)
    else breaking_side && Match.other_side(breaking_side)
    end
  end

  # A player of this match who is in another live match right now
  def busy_player
    MatchPlayer.joins(:match)
               .where(matches: { status: "live", account_id: })
               .where.not(match_id: id)
               .where(player_id: match_players.map(&:player_id))
               .includes(:player, match: :pool_table)
               .first
  end

  def lineup_complete?
    SIDES.all? { |side| side_players(side).size == players_per_side }
  end

  # Players allowed on a side: the team roster in team tournaments, the entry
  # player in individual tournaments, any account player in standalone matches.
  def lineup_pool(side)
    entry = fixture&.public_send("#{side}_entry")
    if entry&.team then entry.team.players.to_a
    elsif entry&.player then [ entry.player ]
    else account.players.to_a
    end
  end

  def pool_table_same_account
    errors.add(:pool_table, :other_account) if pool_table && pool_table.account_id != account_id
  end

  def broadcast
    Broadcaster.match(self)
  end
end
