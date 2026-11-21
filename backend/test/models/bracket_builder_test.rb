require "test_helper"

class BracketBuilderTest < ActiveSupport::TestCase
  test "seed order keeps top seeds apart" do
    assert_equal [ 1, 8, 4, 5, 2, 7, 3, 6 ], BracketBuilder.seed_order(8)
  end

  test "single elimination with byes advances top seeds" do
    t = individual_tournament(6, format: "single_elimination")
    t.start!
    round1 = t.fixtures.where(bracket: "winners", round: 1).order(:position)
    assert_equal 4, round1.size
    assert_equal 2, round1.count { |f| f.status == "finished" }, "seeds 1 and 2 get byes"
    semis = t.fixtures.where(bracket: "winners", round: 2).order(:position)
    assert_equal [ "Player 1", "Player 2" ], semis.map { |f| f.home_entry&.player&.name }
  end

  test "single elimination is played to a winner" do
    t = individual_tournament(4, format: "single_elimination")
    t.start!
    t.fixtures.where(round: 1).each { |f| play(f, "home") }
    final = t.fixtures.find_by(round: 2)
    assert_equal "ready", final.status
    play(final, "away")
    assert_equal "finished", t.reload.status
    assert_equal "Player 2", t.winner_entry.player.name
  end

  test "double elimination: losers bracket and grand final reset" do
    t = individual_tournament(8, format: "double_elimination")
    t.start!
    assert_equal 4 + 2 + 1, t.fixtures.where(bracket: "winners").count
    assert_equal 2 + 2 + 1 + 1, t.fixtures.where(bracket: "losers").count
    assert_equal 2, t.fixtures.where(bracket: "grand_final").count

    # Home always wins, until the grand final
    loop do
      f = t.fixtures.reload.find { |x| x.status == "ready" && x.bracket != "grand_final" }
      break unless f

      play(f, "home")
    end
    gf = t.fixtures.find_by(bracket: "grand_final", round: 1)
    assert_equal "Player 1", gf.home_entry.player.name
    assert_equal "ready", gf.status

    play(gf, "away")
    reset = t.fixtures.find_by(bracket: "grand_final", round: 2)
    assert_equal "ready", reset.status
    play(reset, "away")
    assert_equal "finished", t.reload.status
    assert_equal gf.away_entry, t.winner_entry
  end

  test "double elimination with byes and no reset needed" do
    t = individual_tournament(5, format: "double_elimination")
    t.start!
    50.times do
      f = t.fixtures.reload.find { |x| x.status == "ready" }
      break unless f

      play(f, "home")
    end
    assert_equal "finished", t.reload.status
    assert_equal "void", t.fixtures.find_by(bracket: "grand_final", round: 2).status
    assert_equal "Player 1", t.winner_entry.player.name
  end

  test "round robin plays everyone once" do
    t = individual_tournament(5, format: "round_robin")
    t.start!
    fixtures = t.fixtures.to_a
    assert_equal 10, fixtures.size
    pairs = fixtures.map { |f| [ f.home_entry_id, f.away_entry_id ].sort }
    assert_equal pairs.uniq.size, pairs.size
    fixtures.each { |f| play(f, "home") }
    assert_equal "finished", t.reload.status
    # 10 fixtures, 3 points each
    assert_equal 30, Standings.new(t).rows.sum { |r| r[:points] }
  end
end
