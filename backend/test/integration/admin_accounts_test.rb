require "test_helper"

class AdminAccountsTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  def json = JSON.parse(response.body)

  def login(email)
    post "/api/login", params: { email:, password: "secret123" }
    assert_response :success
    { "Authorization" => "Bearer #{json["token"]}" }
  end

  setup do
    @home = Account.create!(name: "Pool TV")
    @home.users.create!(name: "Admin", email: "admin@example.com", password: "secret123", role: "owner", admin: true)
    @club = Account.create!(name: "Bar do Zé")
    @club.users.create!(name: "Zé", email: "ze@example.com", password: "secret123", role: "owner")
    @admin = login("admin@example.com")
    @owner = login("ze@example.com")
  end

  test "there is no public signup" do
    post "/api/signup", params: { account_name: "X", name: "X", email: "x@example.com", password: "secret123" }
    assert_response :not_found
  end

  test "only platform admins see and create accounts" do
    get "/api/admin/accounts", headers: @owner
    assert_response :forbidden

    get "/api/admin/accounts", headers: @admin
    assert_equal [ "Bar do Zé", "Pool TV" ], json.map { _1["name"] }

    post "/api/admin/accounts", params: { name: "Snooker Clube", owner: { name: "Ana", email: "ana@example.com", password: "secret123" } }, headers: @admin, as: :json
    assert_response :created
    assert_equal [ "ana@example.com" ], json["owners"].map { _1["email"] }
    ana = login("ana@example.com")
    get "/api/me", headers: ana
    assert_equal "Snooker Clube", json["account"]["name"]
    assert_equal "owner", json["user"]["role"]
  end

  test "an admin enters another account and works in it, then goes back" do
    post "/api/admin/accounts/#{@club.id}/enter", headers: @admin
    assert_equal "Bar do Zé", json["account"]["name"]

    post "/api/pool_tables", params: { name: "Mesa do Zé" }, headers: @admin
    assert_response :created
    assert_equal [ "Mesa do Zé" ], @club.pool_tables.pluck(:name)
    get "/api/users", headers: @admin
    assert_equal [ "Zé" ], json.map { _1["name"] }

    post "/api/admin/accounts/#{@home.id}/enter", headers: @admin
    get "/api/me", headers: @admin
    assert_equal "Pool TV", json["account"]["name"]
    assert_nil Session.find_by(token: @admin["Authorization"].split.last).account_id
  end

  test "roles are owner and scorer; the admin flag cannot be set through the app" do
    post "/api/users", params: { name: "A", email: "a@example.com", password: "secret123", role: "admin" }, headers: @owner
    assert_response :unprocessable_content

    post "/api/users", params: { name: "B", email: "b@example.com", password: "secret123", role: "owner", admin: true }, headers: @owner
    assert_response :created
    assert_not User.find_by(email: "b@example.com").admin?
  end

  test "club owners cannot change a platform admin in their club" do
    other = @club.users.create!(name: "Admin 2", email: "admin2@example.com", password: "secret123", role: "owner", admin: true)
    delete "/api/users/#{other.id}", headers: @owner
    assert_response :unprocessable_content
    patch "/api/users/#{other.id}", params: { role: "scorer" }, headers: @owner
    assert_response :unprocessable_content
    assert other.reload.admin?
  end

  test "deleting an account sends admins looking at it back home, but not their own" do
    delete "/api/admin/accounts/#{@home.id}", headers: @admin
    assert_response :unprocessable_content

    post "/api/admin/accounts/#{@club.id}/enter", headers: @admin
    delete "/api/admin/accounts/#{@club.id}", headers: @admin
    assert_response :no_content
    assert_not Account.exists?(@club.id)
    get "/api/me", headers: @admin
    assert_equal "Pool TV", json["account"]["name"]
  end
end
