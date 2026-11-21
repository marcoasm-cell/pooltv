require "test_helper"

class TeamMatchTest < ActiveSupport::TestCase
  def team_tournament(format: "friendly", **opts)
    roster = players(6)
    teams = [ roster[0..2], roster[3..5] ].each_with_index.map do |ps, i|
      team = account.teams.create!(name: "Team #{i + 1}")
      team.set_roster!(ps.map { |p| { player_id: p.id } })
      team
    end
    t = account.tournaments.create!(name: "League", kind: "team", format:, game_type: game_type("pt_pool"),
                                    target: 1, team_match_format: %w[singles singles doubles], **opts)
    teams.each { |team| t.entries.create!(team:) }
    t.start!
    [ t, teams ]
  end

  def play_rubber(match, winner)
    home = match.fixture.home_entry.team.players.first(match.players_per_side).map(&:id)
    away = match.fixture.away_entry.team.players.first(match.players_per_side).map(&:id)
    match.set_lineup!(home:, away:)
    match.start!(table: table("T#{match.id}"), breaking_side: "home")
    match.score!(winner)
  end

  test "a team match has one match per rubber with roster-only lineups" do
    t, = team_tournament
    f = t.fixtures.first
    assert_equal %w[singles singles doubles], f.matches.map(&:kind)
    stranger = account.players.create!(name: "Stranger")
    assert_raises(Errors::InvalidState) { f.matches.first.set_lineup!(home: [ stranger.id ], away: []) }
  end

  test "most rubbers wins, clinching drops the rest" do
    t, = team_tournament(team_target: 2)
    f = t.fixtures.first
    play_rubber(f.matches[0], "away")
    play_rubber(f.matches[1], "away")
    f.reload
    assert_equal "finished", f.status
    assert_equal f.away_entry, f.winner_entry
    assert_equal 2, f.matches.count
  end

  test "racks condition sums racks over all rubbers" do
    t, = team_tournament(team_win_condition: "racks")
    f = t.fixtures.first
    play_rubber(f.matches[0], "home")
    play_rubber(f.matches[1], "away")
    play_rubber(f.matches[2], "away")
    f.reload
    assert_equal [ 1, 2 ], [ f.home_score, f.away_score ]
    assert_equal f.away_entry, f.winner_entry
  end

  test "a tie in an elimination round waits for a decider" do
    t, = team_tournament(format: "single_elimination")
    t.update_column(:team_match_format, %w[singles singles])
    f = t.fixtures.first
    f.matches.destroy_all
    f.send(:create_matches!)
    play_rubber(f.matches[0], "home")
    play_rubber(f.matches[1], "away")
    assert_equal "live", f.reload.status
    decider = f.add_rubber!
    play_rubber(decider, "home")
    assert_equal "finished", f.reload.status
    assert_equal "finished", t.reload.status
  end
end
