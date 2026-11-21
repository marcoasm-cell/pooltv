# A team match outside any league: two teams of TEAM_SIZE players in order,
# plus up to MAX_RESERVES replacements each. It is stored as a two-team
# friendly tournament so the team score, overlays and fixture views work as
# for any team match.
#
# Every player meets every opposing player once, in rounds that rotate the
# away lineup: 1v1, 2v2, 3v3 ... then 1v2, 2v3, 3v1 ... and so on.
#
# Games are dealt to the given tables in turn (game 1 to the first table,
# game 2 to the second, ...). Games of one round never share a player, so
# the tables can play them at the same time.
#
# Each team may name up to MAX_RESERVES replacements; see Fixture#substitute!
#
# The break alternates by round: home breaks in games 1-4, away in 5-8, home
# in 9-12 and away in 13-16. The scorer may still change it before starting.
#
# Every game is a single game (race to 1) worth one point to its team; the
# team match is a race to `race_to`. Once a team gets there the games not
# started yet are dropped (see Fixture#decide_team_match!).
class TeamMatchBuilder
  TEAM_SIZE = 4
  MAX_RESERVES = 2

  def self.pairings(size)
    (0...size).flat_map { |shift| (0...size).map { |i| [ i, (i + shift) % size ] } }
  end

  def initialize(account, game_type:, race_to:, home_team:, away_team:, home_order:, away_order:,
                 home_reserves: [], away_reserves: [], pool_tables: [], name: nil)
    @account = account
    @name = name.to_s.strip.presence
    @game_type = game_type
    @race_to = race_to.to_i
    @teams = { "home" => home_team, "away" => away_team }
    @orders = { "home" => Array(home_order).map(&:to_i), "away" => Array(away_order).map(&:to_i) }
    @reserves = { "home" => Array(home_reserves).map(&:to_i), "away" => Array(away_reserves).map(&:to_i) }
    @pool_tables = Array(pool_tables).compact.uniq
  end

  # Returns the tournament holding the team match
  def build!
    validate!
    size = @orders["home"].size

    Broadcaster.batch { create!(size) }
  end

  private

  def create!(size)
    @account.transaction do
      tournament = @account.tournaments.create!(
        name: @name || "#{@teams['home'].display_name} vs #{@teams['away'].display_name}",
        kind: "team", format: "friendly", game_type: @game_type, target: 1,
        team_match_format: Array.new(size * size, "singles"), team_win_condition: "rubbers", team_target: @race_to
      )
      %w[home away].each_with_index do |side, i|
        tournament.entries.create!(team: @teams[side], seed: i + 1, lineup: {
          "starters" => @orders[side], "reserves" => @reserves[side], "slots" => @orders[side]
        })
      end
      tournament.start!

      matches = tournament.fixtures.first.matches.to_a
      # Next free place in each table's queue (as Match#assign_to! does)
      last_in_queue = @pool_tables.to_h { |t| [ t.id, t.queue.maximum(:queue_position).to_i ] }
      self.class.pairings(size).each_with_index do |(h, a), i|
        match = matches[i]
        match.set_lineup!(home: [ @orders["home"][h] ], away: [ @orders["away"][a] ])
        attrs = { breaking_side: (i / size).even? ? "home" : "away" }
        if @pool_tables.any?
          table = @pool_tables[i % @pool_tables.size]
          attrs.merge!(pool_table: table, queue_position: last_in_queue[table.id] += 1)
        end
        match.update!(attrs)
      end
      tournament
    end
  end

  def validate!
    raise Errors::InvalidState, I18n.t("app_errors.pick_two_teams") if @teams.values.any?(&:nil?) || @teams["home"] == @teams["away"]

    games = TEAM_SIZE * TEAM_SIZE
    raise Errors::InvalidState, I18n.t("app_errors.race_range", games:) unless @race_to.between?(1, games)
    if @orders.values.any? { |ids| ids.size != TEAM_SIZE }
      raise Errors::InvalidState, I18n.t("app_errors.team_size", count: TEAM_SIZE)
    end

    everyone = {}
    @orders.each_key do |side|
      raise Errors::InvalidState, I18n.t("app_errors.max_reserves", count: MAX_RESERVES) if @reserves[side].size > MAX_RESERVES

      ids = @orders[side] + @reserves[side]
      raise Errors::InvalidState, I18n.t("app_errors.player_twice", side: I18n.t("sides.#{side}")) if ids.uniq.size != ids.size

      roster = @teams[side].team_players.pluck(:player_id)
      raise Errors::InvalidState, I18n.t("app_errors.not_on_roster", team: @teams[side].name) unless (ids - roster).empty?

      everyone[side] = ids
    end
    raise Errors::InvalidState, I18n.t("app_errors.player_both_teams") if (everyone["home"] & everyone["away"]).any?
  end
end
