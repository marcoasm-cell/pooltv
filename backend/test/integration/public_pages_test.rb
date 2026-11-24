require "test_helper"

class PublicPagesTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  def json = JSON.parse(response.body)

  setup do
    GameType.seed_built_in!
    club = Account.create!(name: "Bar do Zé")
    club.users.create!(name: "Zé", email: "ze@example.com", password: "secret123", role: "owner")
    post "/api/login", params: { email: "ze@example.com", password: "secret123" }
    @auth = { "Authorization" => "Bearer #{json["token"]}" }
    @table = post("/api/pool_tables", params: { name: "Mesa 1" }, headers: @auth) && json
    @gt = GameType.find_by(key: "pt_pool")
    @players = %w[Ana Rui Eva Luís].map { |n| post("/api/players", params: { name: n }, headers: @auth) && json }
  end

  test "a match is followed without signing in" do
    post "/api/matches", params: { game_type_id: @gt.id, target: 3, home: [ @players[0]["id"] ], away: [ @players[1]["id"] ], pool_table_id: @table["id"] }, headers: @auth
    match = json
    assert match["public_token"].present?
    post "/api/matches/#{match["id"]}/start", params: { breaking_side: "home" }, headers: @auth

    assert_broadcasts("public:match:#{match["id"]}", 1) do
      post "/api/matches/#{match["id"]}/score", params: { side: "home" }, headers: @auth
    end

    get "/api/public/matches/#{match["public_token"]}"
    assert_response :success
    assert_equal 1, json.dig("match", "home", "score")
    assert_equal "Bar do Zé", json.dig("branding", "name")
    assert_equal [ "Mesa 1" ], json["tables"].map { _1["name"] }

    get "/api/public/matches/#{match["id"]}"
    assert_response :not_found
  end

  test "a tournament shows its fixtures and its live matches" do
    post "/api/tournaments", params: { name: "Open", game_type_id: @gt.id, format: "single_elimination", pool_table_ids: [ @table["id"] ] }, headers: @auth, as: :json
    tour = json
    @players.each { |p| post "/api/tournaments/#{tour["id"]}/entries", params: { player_id: p["id"] }, headers: @auth }

    post "/api/tournaments/#{tour["id"]}/start", headers: @auth
    assert broadcasts("public:tournament:#{tour["id"]}").any?

    get "/api/public/tournaments/#{tour["public_token"]}"
    assert_response :success
    assert_equal "running", json.dig("tournament", "status")
    assert_equal 3, json.dig("tournament", "fixtures").size
    match = json.dig("tournament", "fixtures").flat_map { _1["matches"] }.first
    assert_equal tour["public_token"], Match.find(match["id"]).tournament.public_token

    post "/api/matches/#{match["id"]}/start", params: { breaking_side: "home" }, headers: @auth
    assert_broadcasts("public:tournament:#{tour["id"]}", 1) do
      post "/api/matches/#{match["id"]}/score", params: { side: "home" }, headers: @auth
    end

    # The overlay knows where to send the QR code
    get "/api/overlay/tables/#{@table["overlay_token"]}"
    assert_equal tour["public_token"], json.dig("table", "current_match", "tournament", "public_token")
  end
end
