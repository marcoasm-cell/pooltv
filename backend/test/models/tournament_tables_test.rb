require "test_helper"

class TournamentTablesTest < ActiveSupport::TestCase
  test "first-round matches are shared out over the chosen tables" do
    t1, t2 = table("A"), table("B")
    tour = individual_tournament(8, format: "single_elimination", pool_table_ids: [ t1.id, t2.id ])
    tour.start!

    tables = tour.fixtures.where(round: 1).flat_map(&:matches).map(&:pool_table_id)
    assert_equal({ t1.id => 2, t2.id => 2 }, tables.tally)
  end

  test "a match that becomes ready goes to the least busy table" do
    t1, t2 = table("A"), table("B")
    tour = individual_tournament(4, format: "single_elimination", pool_table_ids: [ t1.id, t2.id ])
    tour.start!
    first, second = tour.fixtures.where(round: 1).to_a

    play(first, "home", on: t1)
    play(second, "home", on: t2)

    final = tour.fixtures.find_by(round: 2).matches.first
    assert_equal t1.id, final.pool_table_id
  end

  test "without tables nothing is assigned" do
    tour = individual_tournament(4, format: "round_robin")
    tour.start!

    assert tour.fixtures.flat_map(&:matches).all? { |m| m.pool_table_id.nil? }
  end

  test "inactive tables are skipped" do
    t1, t2 = table("A"), table("B")
    t2.update!(active: false)
    tour = individual_tournament(4, format: "round_robin", pool_table_ids: [ t1.id, t2.id ])
    tour.start!

    assert tour.fixtures.flat_map(&:matches).all? { |m| m.pool_table_id == t1.id }
  end

  test "tables of another account are refused" do
    other = Account.create!(name: "Other").pool_tables.create!(name: "X")
    tour = account.tournaments.new(name: "Open", game_type: game_type, pool_table_ids: [ other.id ])

    assert_not tour.valid?
    assert tour.errors.key?(:pool_table_ids)
  end

  test "unplaced matches get a table once tables are chosen" do
    tour = individual_tournament(4, format: "round_robin")
    tour.start!
    t1 = table("A")

    tour.update!(pool_table_ids: [ t1.id ])
    tour.auto_assign_unplaced!

    assert tour.fixtures.flat_map { |f| f.matches.reload }.all? { |m| m.pool_table_id == t1.id }
  end
end
