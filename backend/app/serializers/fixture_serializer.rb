module FixtureSerializer
  module_function

  ENTRY_PRELOAD = [ :team, { player: { photo_attachment: :blob } } ].freeze

  # Loads what call reads for many fixtures at once. Fixtures of one tournament
  # share a single tournament object, so its bracket (read by round_label) is
  # loaded once rather than once per fixture.
  def preload(fixtures, matches: true)
    fixtures = fixtures.compact
    return fixtures if fixtures.empty?

    associations = [ :tournament, { home_entry: ENTRY_PRELOAD }, { away_entry: ENTRY_PRELOAD } ]
    associations << { matches: Match::SIDES_PRELOAD } if matches
    ActiveRecord::Associations::Preloader.new(records: fixtures, associations:).call
    fixtures.group_by(&:tournament_id).each_value do |group|
      shared = group.first.tournament
      group.each { |f| f.association(:tournament).target = shared }
    end
    fixtures
  end

  def call(fixture, matches: true)
    preload([ fixture ], matches:)
    data = fixture.slice(:id, :tournament_id, :bracket, :round, :position, :status, :home_score, :away_score,
                         :home_bye, :away_bye, :winner_to_id, :winner_to_slot, :loser_to_id, :loser_to_slot)
    data.merge!(
      round_label: round_label(fixture),
      home: EntrySerializer.call(fixture.home_entry),
      away: EntrySerializer.call(fixture.away_entry),
      winner_entry_id: fixture.winner_entry_id
    )
    data[:matches] = fixture.matches.map { |m| MatchSerializer.call(m, fixture: false) } if matches
    data
  end

  # Which round a fixture is, for clients to name in their own language:
  # { key: "final" | "semi_final" | "quarter_final" | "round" | "winners_final" |
  #   "losers_round" | "grand_final" | "grand_final_reset" | "friendly", round: n }
  def round_label(fixture)
    t = fixture.tournament
    key =
      case fixture.bracket
      when "grand_final" then fixture.round == 1 ? "grand_final" : "grand_final_reset"
      when "losers" then "losers_round"
      when "group" then t.format == "friendly" ? "friendly" : "round"
      else
        last = t.fixtures.select { |f| f.bracket == "winners" }.map(&:round).max
        case last - fixture.round
        when 0 then t.format == "double_elimination" ? "winners_final" : "final"
        when 1 then "semi_final"
        when 2 then "quarter_final"
        else "round"
        end
      end
    { key:, round: fixture.round }
  end
end
