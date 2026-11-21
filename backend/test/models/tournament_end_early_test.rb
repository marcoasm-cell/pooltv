require "test_helper"

class TournamentEndEarlyTest < ActiveSupport::TestCase
  test "ending a bracket early abandons the live match and voids what is left" do
    t = individual_tournament(4, format: "single_elimination")
    t.start!
    first, second = t.fixtures.where(round: 1).order(:position).to_a
    play(first, "home")
    tbl = table("Main")
    live = second.reload.matches.first
    live.start!(table: tbl, breaking_side: "home")
    live.score!("away")

    t.end_early!

    assert_equal "finished", t.reload.status
    assert t.ended_early
    assert_nil t.winner_entry, "no champion when the final was never played"
    assert_equal "finished", first.reload.status
    assert_equal %w[void void], [ second.reload.status, t.fixtures.find_by(round: 2).status ]
    assert_equal "finished", live.reload.status
    assert_nil live.winner_side
    assert_nil tbl.reload.current_match_id
    assert_raises(Errors::InvalidState) { live.undo! }
  end

  test "a round robin ended early keeps the standings leader" do
    t = individual_tournament(3, format: "round_robin")
    t.start!
    played = t.fixtures.find { |f| f.status == "ready" }
    play(played, "home")
    t.end_early!

    assert_equal played.reload.winner_entry, t.reload.winner_entry
    assert_equal 0, t.fixtures.where(status: %w[pending ready live]).count
    assert_equal 0, Match.where(fixture: t.fixtures, status: "scheduled").count
  end

  test "only a running tournament can be ended, and reset clears the flag" do
    t = individual_tournament(2, format: "single_elimination")
    assert_raises(Errors::InvalidState) { t.end_early! }
    t.start!
    t.end_early!
    assert_raises(Errors::InvalidState) { t.end_early! }
    t.reset!
    assert_not t.reload.ended_early
  end
end
