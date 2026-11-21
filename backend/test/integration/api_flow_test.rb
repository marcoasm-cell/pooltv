require "test_helper"

class ApiFlowTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  def json = JSON.parse(response.body)

  setup do
    GameType.seed_built_in!
    club = Account.create!(name: "Bar do Zé")
    club.users.create!(name: "Zé", email: "ze@example.com", password: "secret123", role: "owner")
    post "/api/login", params: { email: "ze@example.com", password: "secret123" }
    assert_response :success
    @auth = { "Authorization" => "Bearer #{json["token"]}" }
  end

  test "errors are in Portuguese by default and in English on request" do
    post "/api/login", params: { email: "ze@example.com", password: "wrong" }
    assert_equal "Email ou palavra-passe errados", json["error"]

    post "/api/login", params: { email: "ze@example.com", password: "wrong" }, headers: { "Accept-Language" => "en-GB,en;q=0.9" }
    assert_equal "Wrong email or password", json["error"]

    post "/api/players", params: { name: "" }, headers: @auth
    assert_equal "Nome não pode estar em branco", json["error"]

    post "/api/players", params: { name: "" }, headers: @auth.merge("Accept-Language" => "en")
    assert_equal "Name can't be blank", json["error"]

    get "/api/players/0", headers: @auth.merge("Accept-Language" => "pt")
    assert_equal "Não encontrado", json["error"]
  end

  test "quick match on a table shows on both overlays" do
    post "/api/pool_tables", params: { name: "Table 1" }, headers: @auth
    table = json
    a = post("/api/players", params: { name: "Ana" }, headers: @auth) && json
    b = post("/api/players", params: { name: "Rui" }, headers: @auth) && json
    gt = GameType.find_by(key: "pt_pool")

    post "/api/matches", params: { game_type_id: gt.id, target: 2, name: " Final do clube ", home: [ a["id"] ], away: [ b["id"] ], pool_table_id: table["id"] }, headers: @auth
    assert_response :created
    assert_equal "Final do clube", json["name"]
    match_id = json["id"]
    post "/api/matches/#{match_id}/start", params: { breaking_side: "home" }, headers: @auth
    assert_response :success

    assert_broadcasts("table:#{table["id"]}", 1) do
      post "/api/matches/#{match_id}/score", params: { side: "away" }, headers: @auth
    end

    get "/api/overlay/tables/#{table["overlay_token"]}"
    assert_response :success
    assert_equal [ "Ana", "Rui" ], [ json.dig("table", "current_match", "home", "name"), json.dig("table", "current_match", "away", "name") ]
    assert_equal 1, json.dig("table", "current_match", "away", "score")

    get "/api/account", headers: @auth
    get "/api/overlay/all/#{json["overlay_token"]}"
    assert_equal [ "Table 1" ], json["tables"].map { |t| t["name"] }

    get "/api/overlay/tables/wrong"
    assert_response :not_found
  end

  test "regenerating a table token kills the old overlay link" do
    post "/api/pool_tables", params: { name: "Table 1" }, headers: @auth
    old = json
    post "/api/pool_tables/#{old["id"]}/regenerate_token", headers: @auth
    get "/api/overlay/tables/#{old["overlay_token"]}"
    assert_response :not_found
  end

  test "scorers cannot configure" do
    post "/api/users", params: { name: "Scorer", email: "s@example.com", password: "secret123", role: "scorer" }, headers: @auth
    post "/api/login", params: { email: "s@example.com", password: "secret123" }
    scorer = { "Authorization" => "Bearer #{json["token"]}" }
    post "/api/pool_tables", params: { name: "T" }, headers: scorer
    assert_response :forbidden
    get "/api/pool_tables", headers: scorer
    assert_response :success
    assert_nil json.first&.dig("overlay_token")
  end

  test "FPB import is for admins and reports what it did" do
    fake = FpbTest::FakeClient.new(FpbTest.new("fixtures"))
    Fpb::Client.define_singleton_method(:new) { fake }

    post "/api/fpb/import", params: { teams: [ "EQP7605" ] }, headers: @auth, as: :json
    assert_response :success
    assert_equal 1, json["teams_created"]
    get "/api/teams", headers: @auth
    assert_equal [ "EQP7605" ], json.map { _1["fpb_code"] }
    assert_equal [ 8796, 1291 ], json.first["roster"].map { _1["fpb_license"] }

    post "/api/users", params: { name: "Scorer", email: "s@example.com", password: "secret123", role: "scorer" }, headers: @auth
    post "/api/login", params: { email: "s@example.com", password: "secret123" }
    post "/api/fpb/sync", headers: { "Authorization" => "Bearer #{json["token"]}" }
    assert_response :forbidden
  ensure
    Fpb::Client.singleton_class.remove_method(:new) if Fpb::Client.singleton_methods(false).include?(:new)
  end

  test "requests without a token are refused" do
    get "/api/players"
    assert_response :unauthorized
  end

  test "tournament tables are set on create and can be changed while running" do
    t1 = post("/api/pool_tables", params: { name: "A" }, headers: @auth) && json
    t2 = post("/api/pool_tables", params: { name: "B" }, headers: @auth) && json
    gt = GameType.find_by(key: "pt_pool")

    post "/api/tournaments", params: { name: "Open", game_type_id: gt.id, format: "round_robin", pool_table_ids: [ t1["id"], t2["id"] ] }, headers: @auth, as: :json
    assert_response :created
    tour = json
    assert_equal [ t1["id"], t2["id"] ], tour["pool_table_ids"]

    3.times do |i|
      player = post("/api/players", params: { name: "P#{i}" }, headers: @auth) && json
      post "/api/tournaments/#{tour["id"]}/entries", params: { player_id: player["id"] }, headers: @auth
    end
    post "/api/tournaments/#{tour["id"]}/start", headers: @auth
    assert_response :success
    assert_equal [ t1["id"], t2["id"] ].sort, Match.where.not(pool_table_id: nil).distinct.pluck(:pool_table_id).sort

    patch "/api/tournaments/#{tour["id"]}", params: { pool_table_ids: [] }, headers: @auth, as: :json
    assert_response :success
    assert_equal [], json["pool_table_ids"]
  end
end
