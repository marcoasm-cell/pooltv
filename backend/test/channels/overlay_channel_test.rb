require "test_helper"

class OverlayChannelTest < ActionCable::Channel::TestCase
  test "streams a table by its token" do
    t = table
    subscribe token: t.overlay_token
    assert subscription.confirmed?
    assert_has_stream "table:#{t.id}"
  end

  test "streams all tables by the account token" do
    subscribe token: account.overlay_token
    assert_has_stream "account:#{account.id}"
  end

  test "rejects unknown tokens" do
    subscribe token: "nope"
    assert subscription.rejected?
  end
end
