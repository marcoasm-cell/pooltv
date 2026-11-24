require "test_helper"

class PublicChannelTest < ActionCable::Channel::TestCase
  setup { GameType.seed_built_in! }

  test "streams a tournament by its public token" do
    t = account.tournaments.create!(name: "Open", game_type: GameType.find_by(key: "pt_pool"))
    subscribe kind: "tournament", token: t.public_token
    assert subscription.confirmed?
    assert_has_stream "public:tournament:#{t.id}"
  end

  test "rejects unknown tokens and the overlay tokens" do
    subscribe kind: "match", token: "nope"
    assert subscription.rejected?
    subscribe kind: "tournament", token: account.overlay_token
    assert subscription.rejected?
  end
end
