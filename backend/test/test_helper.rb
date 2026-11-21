ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module PoolTvHelpers
  def account
    @account ||= Account.create!(name: "Club")
  end

  def game_type(key = "9_ball")
    GameType.seed_built_in!
    GameType.find_by!(account_id: nil, key:)
  end

  def table(name = "Table 1")
    account.pool_tables.create!(name:)
  end

  def players(n)
    (1..n).map { |i| account.players.create!(name: "Player #{i}") }
  end

  def individual_tournament(n, format:, target: 2, **opts)
    t = account.tournaments.create!(name: "Open", game_type: game_type, format:, target:, **opts)
    players(n).each_with_index { |p, i| t.entries.create!(player: p, seed: i + 1) }
    t
  end

  # Plays a fixture's single match to a win for the given side
  def play(fixture, winner_side, on: nil)
    match = fixture.reload.matches.first
    match.start!(table: on || table("T#{fixture.id}"), breaking_side: "home")
    match.target.times { match.score!(winner_side) }
    match
  end
end

class ActiveSupport::TestCase
  include PoolTvHelpers
end
