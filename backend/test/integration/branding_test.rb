require "test_helper"

class BrandingTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  def json = JSON.parse(response.body)
  def png = fixture_file_upload("logo.png", "image/png")

  setup do
    club = Account.create!(name: "Bar do Zé")
    club.users.create!(name: "Zé", email: "ze@example.com", password: "secret123", role: "owner")
    post "/api/login", params: { email: "ze@example.com", password: "secret123" }
    @auth = { "Authorization" => "Bearer #{json["token"]}" }
    post "/api/pool_tables", params: { name: "Table 1" }, headers: @auth
    @table = json
  end

  test "club logo and sponsors reach both overlays" do
    put "/api/account/logo", params: { logo: png }, headers: @auth
    assert_response :success
    assert_match %r{/rails/active_storage/}, json["logo_url"]
    token = json["overlay_token"]

    post "/api/sponsors", params: { name: "Café Central", logo: png }, headers: @auth
    assert_response :created
    post "/api/sponsors", params: { name: "Sem logo" }, headers: @auth
    post "/api/sponsors", params: { name: "Desligado", logo: png, active: false }, headers: @auth
    assert_equal [ "Café Central", "Sem logo", "Desligado" ], json.map { |s| s["name"] }

    get "/api/overlay/tables/#{@table["overlay_token"]}"
    branding = json["branding"]
    assert_equal "Bar do Zé", branding["name"]
    assert branding["logo_url"]
    # Only active sponsors with a logo go on air
    assert_equal [ "Café Central" ], branding["sponsors"].map { |s| s["name"] }
    assert_equal 8, json.dig("table", "overlay", "sponsor_seconds")

    get "/api/overlay/all/#{token}"
    assert_equal [ "Café Central" ], json.dig("branding", "sponsors").map { |s| s["name"] }
  end

  test "changes are pushed to every overlay" do
    assert_broadcasts("table:#{@table["id"]}", 1) do
      post "/api/sponsors", params: { name: "Café Central", logo: png }, headers: @auth
    end
    ids = json.map { |s| s["id"] }
    post "/api/sponsors", params: { name: "Taberna", logo: png }, headers: @auth
    ids << json.last["id"]

    put "/api/sponsors/order", params: { ids: ids.reverse }, headers: @auth
    assert_equal [ "Taberna", "Café Central" ], json.map { |s| s["name"] }

    patch "/api/sponsors/#{ids.first}", params: { active: false }, headers: @auth
    assert_equal false, json.find { |s| s["id"] == ids.first }["active"]

    account = Account.find_by!(name: "Bar do Zé")
    assert_broadcasts("account:#{account.id}", 1) do
      delete "/api/sponsors/#{ids.last}", headers: @auth
    end
    assert_equal [ "Café Central" ], json.map { |s| s["name"] }
  end

  test "only images are accepted, and only from admins" do
    put "/api/account/logo", params: { logo: fixture_file_upload("logo.txt", "text/plain") }, headers: @auth.merge("Accept-Language" => "en")
    assert_response :unprocessable_content
    assert_match "PNG, JPEG or WebP", json["error"]

    post "/api/sponsors", params: { name: "X", logo: fixture_file_upload("logo.txt", "text/plain") }, headers: @auth
    assert_response :unprocessable_content
    get "/api/sponsors", headers: @auth
    assert_empty json, "a sponsor with a bad logo is not saved"

    post "/api/users", params: { name: "Scorer", email: "s@example.com", password: "secret123", role: "scorer" }, headers: @auth
    post "/api/login", params: { email: "s@example.com", password: "secret123" }
    post "/api/sponsors", params: { name: "X" }, headers: { "Authorization" => "Bearer #{json["token"]}" }
    assert_response :forbidden
  end
end
