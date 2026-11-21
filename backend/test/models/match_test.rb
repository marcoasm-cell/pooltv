require "test_helper"

class MatchTest < ActiveSupport::TestCase
  def quick_match(key: "9_ball", target: 3)
    p1, p2 = players(2)
    m = account.matches.create!(game_type: game_type(key), target:)
    m.set_lineup!(home: [ p1.id ], away: [ p2.id ])
    m
  end

  test "racks alternate the break and finish at the target" do
    m = quick_match
    t = table
    m.start!(table: t, breaking_side: "home")
    assert_equal m, t.reload.current_match
    m.score!("home")
    assert_equal "away", m.breaking_side
    m.score!("away")
    m.score!("home")
    m.score!("home")
    assert m.finished?
    assert_equal "home", m.winner_side
    assert_equal [ 3, 1 ], [ m.home_score, m.away_score ]
  end

  test "undo reopens a finished match and restores the breaker" do
    m = quick_match(target: 1)
    m.start!(table: table, breaking_side: "away")
    m.score!("away")
    assert m.finished?
    m.undo!
    assert m.live?
    assert_equal 0, m.away_score
    assert_equal "away", m.breaking_side
    assert_raises(Errors::InvalidState) { m.undo! }
  end

  test "points games take negative points for fouls" do
    m = quick_match(key: "straight_pool", target: 100)
    m.start!(table: table, breaking_side: "home")
    m.score!("home", points: 14)
    m.score!("home", points: -1)
    assert_equal 13, m.home_score
    m.score!("away", points: 100)
    assert m.finished?
  end

  test "a match needs its lineup and a free table" do
    p1, p2 = players(2)
    t = table
    m = account.matches.create!(game_type: game_type, target: 3)
    assert_raises(Errors::InvalidState) { m.start!(table: t) }
    m.set_lineup!(home: [ p1.id ], away: [ p2.id ])
    m.start!(table: t)
    other = account.matches.create!(game_type: game_type, target: 3)
    other.set_lineup!(home: [ p1.id ], away: [ p2.id ])
    assert_raises(Errors::InvalidState) { other.start!(table: t) }
  end

  test "a player cannot be live on two tables" do
    p1, p2, p3 = players(3)
    first = account.matches.create!(game_type: game_type, target: 3)
    first.set_lineup!(home: [ p1.id ], away: [ p2.id ])
    first.start!(table: table("A"))
    second = account.matches.create!(game_type: game_type, target: 3)
    second.set_lineup!(home: [ p3.id ], away: [ p1.id ])
    error = assert_raises(Errors::InvalidState) { second.start!(table: table("B")) }
    assert_match "Player 1 já está a jogar na A", error.message
  end

  test "undo after the next round started is refused" do
    t = individual_tournament(4, format: "single_elimination", target: 1)
    t.start!
    semis = t.fixtures.where(round: 1).to_a
    m1 = play(semis[0], "home")
    play(semis[1], "home")
    final = t.fixtures.find_by(round: 2)
    final.matches.first.start!(table: table("Final"), breaking_side: "home")
    assert_raises(Errors::InvalidState) { m1.reload.undo! }
  end

  test "undo before the next round takes the winner back" do
    t = individual_tournament(4, format: "single_elimination", target: 1)
    t.start!
    semi = t.fixtures.find_by(round: 1, position: 1)
    m = play(semi, "home")
    final = t.fixtures.find_by(round: 2)
    assert final.home_entry
    m.reload.undo!
    assert_nil final.reload.home_entry
    assert_equal "live", semi.reload.status
  end
end
