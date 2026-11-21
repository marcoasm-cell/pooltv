require "test_helper"

class TeamMatchBuilderTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  def team(name, roster)
    t = account.teams.create!(name:)
    t.set_roster!(roster.map { |p| { player_id: p.id } })
    t
  end

  def build(home_order:, away_order:, **opts)
    TeamMatchBuilder.new(account, game_type: game_type("pt_pool"), race_to: 9,
                         home_team: @home, away_team: @away, home_order:, away_order:, **opts).build!
  end

  setup do
    ps = players(12)
    @h = ps[0..3]
    @a = ps[4..7]
    @home_reserves = ps[8..9]
    @home = team("Sharks", @h + @home_reserves)
    @away = team("Tigers", @a + ps[10..11])
  end

  test "names the team match after the teams unless given a name" do
    assert_equal "Sharks vs Tigers", build(home_order: @h.map(&:id), away_order: @a.map(&:id)).name
    assert_equal "Taça de Natal", build(home_order: @h.map(&:id), away_order: @a.map(&:id), name: " Taça de Natal ").name
  end

  test "home breaks the first round, away the second, and so on" do
    matches = build(home_order: @h.map(&:id), away_order: @a.map(&:id)).fixtures.first.matches.order(:rubber_number)
    assert_equal %w[home away home away].flat_map { |s| [ s ] * 4 }, matches.map(&:breaking_side)
  end

  test "pairs i v i first, then rotates the away order" do
    assert_equal [ [ 0, 0 ], [ 1, 1 ], [ 0, 1 ], [ 1, 0 ] ], TeamMatchBuilder.pairings(2)
    assert_equal [ [ 0, 1 ], [ 1, 2 ], [ 2, 3 ], [ 3, 0 ] ], TeamMatchBuilder.pairings(4)[4..7]
  end

  test "creates one rubber per pairing with the chosen order, queued on the table" do
    home_order = @h.reverse.map(&:id)
    pool_table = table
    t = build(home_order:, away_order: @a.map(&:id), pool_tables: [ pool_table ])
    matches = t.fixtures.first.matches.to_a

    assert_equal 16, matches.size
    assert_equal [ @h[3], @a[0] ], [ matches[0].side_players("home").first, matches[0].side_players("away").first ]
    assert_equal [ @h[3], @a[1] ], [ matches[4].side_players("home").first, matches[4].side_players("away").first ]
    assert_equal [ @h[0], @a[0] ], [ matches[7].side_players("home").first, matches[7].side_players("away").first ]
    assert matches.all? { |m| m.pool_table == pool_table }
    assert_equal matches.map(&:id), pool_table.queue.map(&:id)
  end

  test "deals the games to several tables in turn" do
    t1 = table("T1")
    t2 = table("T2")
    t = build(home_order: @h.map(&:id), away_order: @a.map(&:id), pool_tables: [ t1, t2 ])
    matches = t.fixtures.first.matches.to_a

    assert_equal matches.each_slice(2).map(&:first).map(&:id), t1.queue.map(&:id)
    assert_equal matches.each_slice(2).map(&:last).map(&:id), t2.queue.map(&:id)
    # The first game on each table can start at once
    t1.queue.first.start!(table: t1, breaking_side: "home")
    t2.queue.first.start!(table: t2, breaking_side: "home")
    assert_equal 2, t.fixtures.first.matches.count(&:live?)
  end

  test "broadcasts each table and game once, after building" do
    t1 = table("T1")
    t2 = table("T2")
    assert_broadcasts(t1.broadcast_stream, 1) do
      assert_broadcasts(t2.broadcast_stream, 1) do
        # 16 games + 1 fixture + 2 tables
        assert_broadcasts(account.broadcast_stream, 19) do
          build(home_order: @h.map(&:id), away_order: @a.map(&:id), pool_tables: [ t1, t2 ])
        end
      end
    end
  end

  def home_players(fixture, slot)
    pairings = TeamMatchBuilder.pairings(4)
    fixture.matches.reload.select { |m| pairings[m.rubber_number - 1][0] == slot }.map { |m| m.side_players("home").first }
  end

  test "a replacement takes over the unplayed games of a position" do
    t = build(home_order: @h.map(&:id), away_order: @a.map(&:id), home_reserves: @home_reserves.map(&:id))
    f = t.fixtures.first
    first = f.matches.first
    first.start!(table: table, breaking_side: "home")

    f.substitute!("home", 0, @home_reserves[0].id)
    played, *rest = home_players(f, 0)
    assert_equal @h[0], played
    assert_equal [ @home_reserves[0] ] * 3, rest
    assert_equal [ @home_reserves[0].id, *@h[1..].map(&:id) ], f.home_entry.reload.lineup["slots"]
  end

  test "a replaced starter only comes back into their own position" do
    t = build(home_order: @h.map(&:id), away_order: @a.map(&:id), home_reserves: @home_reserves.map(&:id))
    f = t.fixtures.first
    f.substitute!("home", 0, @home_reserves[0].id)

    assert_raises(Errors::InvalidState) { f.substitute!("home", 1, @h[0].id) }
    assert_raises(Errors::InvalidState) { f.substitute!("home", 1, @home_reserves[0].id) }
    assert_raises(Errors::InvalidState) { f.substitute!("home", 1, @a[0].id) }

    f.substitute!("home", 0, @h[0].id)
    assert_equal [ @h[0] ] * 4, home_players(f, 0)
    # Back on the bench, the replacement can go anywhere
    f.substitute!("home", 2, @home_reserves[0].id)
    assert_equal [ @home_reserves[0] ] * 4, home_players(f, 2)
  end

  test "at most two replacements" do
    assert_raises(Errors::InvalidState) do
      build(home_order: @h.map(&:id), away_order: @a.map(&:id), home_reserves: [ *@home_reserves.map(&:id), @a[0].id ])
    end
  end

  test "single games in a team race, decided as soon as a team gets there" do
    t = TeamMatchBuilder.new(account, game_type: game_type("pt_pool"), race_to: 3, home_team: @home, away_team: @away,
                             home_order: @h.map(&:id), away_order: @a.map(&:id)).build!
    f = t.fixtures.first
    assert f.matches.all? { |m| m.target == 1 }

    pool_table = table
    3.times do
      m = f.matches.reload.find(&:scheduled?)
      m.start!(table: pool_table, breaking_side: "home")
      m.score!("away")
    end
    f.reload
    assert_equal "finished", f.status
    assert_equal f.away_entry, f.winner_entry
    assert_equal [ 0, 3 ], [ f.home_score, f.away_score ]
    assert_equal 3, f.matches.count
  end

  test "the race fits in the 16 games" do
    assert_raises(Errors::InvalidState) do
      TeamMatchBuilder.new(account, game_type: game_type("pt_pool"), race_to: 17, home_team: @home, away_team: @away,
                           home_order: @h.map(&:id), away_order: @a.map(&:id)).build!
    end
  end

  test "teams play 4 against 4" do
    assert_raises(Errors::InvalidState) { build(home_order: @h.first(3).map(&:id), away_order: @a.first(3).map(&:id)) }
  end

  test "rejects uneven lineups and players off the roster" do
    assert_raises(Errors::InvalidState) { build(home_order: @h.map(&:id), away_order: @a.first(3).map(&:id)) }
    assert_raises(Errors::InvalidState) { build(home_order: [ @a[0].id ], away_order: [ @a[1].id ]) }
  end
end
