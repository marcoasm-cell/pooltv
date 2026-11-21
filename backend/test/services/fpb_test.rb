require "test_helper"

class FpbTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def fixture(name) = file_fixture("fpb/#{name}").read

  # Answers from the saved pages instead of the portal
  class FakeClient
    def initialize(test) = @test = test
    def athletes = Fpb::Client.parse_athletes(@test.fixture("atletas.json"))
    def team(code) = Fpb::Client.parse_team(@test.fixture("equipa.html")).merge(code:)
    def photo(file) = (@test.file_fixture("fpb/foto.jpg").binread if file == "img_atleta_08007.png")
  end

  test "parses competitions and the teams entered" do
    html = fixture("competicoes.html")
    comps = Fpb::Client.parse_competitions(html)
    assert_equal "cCNPOM0008-26", comps[:selected]
    assert_equal "POM Campeonato Distrital - Lisboa - 1.ª Divisão", comps[:competitions].last[:name]

    teams = Fpb::Client.parse_teams(html)
    assert_equal %w[EQP7605 EQP7625], teams.pluck(:code)
    assert_equal({ code: "EQP7605", name: "CB Canelas - Fastlane", club: "CB Canelas", status: "Confirmado", district: "Porto" }, teams.first)
  end

  test "parses a team roster with licences" do
    team = Fpb::Client.parse_team(fixture("equipa.html"))
    assert_equal "CB Canelas - Fastlane", team[:name]
    assert_equal "CB Canelas", team[:club]
    assert_equal [ { license: 8796, name: "Bruno Bernardo", photo: "img_atleta_08007.png" },
                   { license: 1291, name: "João Cardoso", photo: nil } ], team[:roster]
  end

  test "parses athletes and trims names" do
    athletes = Fpb::Client.parse_athletes(fixture("atletas.json"))
    assert_equal [ 12121, 8796 ], athletes.pluck(:license)
    assert_equal "Cleberson Serafim", athletes.first[:name]
    assert_equal "AB Retiro", athletes.first[:club]
    assert_equal [ nil, "img_atleta_08007.png" ], athletes.pluck(:photo)
  end

  test "an unexpected answer is reported as such" do
    assert_raises(Errors::FpbUnavailable) { Fpb::Client.parse_athletes("<html>error</html>") }
  end

  test "imports a team with its roster and an athlete" do
    result = Fpb::Importer.new(account, client: FakeClient.new(self)).import(team_codes: [ "EQP7605" ], licenses: [ 12121 ])
    assert_equal({ players_created: 3, players_updated: 0, teams_created: 1, teams_updated: 0, roster_added: 2, photos_queued: 1 }, result)

    team = account.teams.find_by!(fpb_code: "EQP7605")
    assert_equal "CB Canelas - Fastlane", team.name
    assert_equal [ "Bruno Bernardo", "João Cardoso" ], team.players.map(&:name)
    assert_equal [ 8796, 1291 ], team.players.map(&:fpb_license)
    assert_equal "PT", team.players.first.country_code
    assert_equal "AB Retiro", account.players.find_by!(fpb_license: 12121).fpb_club
  end

  test "importing again adds nothing and keeps local changes to the roster" do
    importer = -> { Fpb::Importer.new(account, client: FakeClient.new(self)) }
    importer.call.import(team_codes: [ "EQP7605" ])
    team = account.teams.find_by!(fpb_code: "EQP7605")
    local = account.players.create!(name: "Local Guest")
    team.set_roster!(team.team_players.map { { player_id: _1.player_id, captain: true } } + [ { player_id: local.id } ])
    account.players.find_by!(fpb_license: 8796).update!(name: "Old name", nickname: "Bruno B.")

    result = importer.call.sync
    assert_equal({ players_created: 0, players_updated: 1, teams_created: 0, teams_updated: 0, roster_added: 0, photos_queued: 1 }, result)
    team.reload
    assert_equal [ "Bruno Bernardo", "João Cardoso", "Local Guest" ], team.players.map(&:name)
    assert team.team_players.first.captain
    assert_equal "Bruno B.", account.players.find_by!(fpb_license: 8796).nickname
  end

  test "downloads photos after the import, and again only when they change" do
    client = FakeClient.new(self)
    assert_enqueued_with(job: FpbPhotosJob) do
      Fpb::Importer.new(account, client:).import(team_codes: [ "EQP7605" ])
    end
    # What the job does, with the saved photo instead of the portal
    Fpb::Importer.download_photos(enqueued_jobs.last[:args].first, client:)

    bruno = account.players.find_by!(fpb_license: 8796)
    assert bruno.photo.attached?
    assert_equal "image/jpeg", bruno.photo.content_type
    assert_equal "img_atleta_08007.png", bruno.fpb_photo
    assert_match %r{\A/rails/active_storage/representations/proxy/}, PlayerSerializer.call(bruno)[:photo_url]
    assert_nil PlayerSerializer.call(account.players.find_by!(fpb_license: 1291))[:photo_url]

    result = Fpb::Importer.new(account, client:).import(team_codes: [ "EQP7605" ])
    assert_equal 0, result[:photos_queued]
  end

  test "links players and teams created by hand with the same name" do
    player = account.players.create!(name: "joão cardoso")
    team = account.teams.create!(name: "CB Canelas - Fastlane")
    Fpb::Importer.new(account, client: FakeClient.new(self)).import(team_codes: [ "EQP7605" ])

    assert_equal 1291, player.reload.fpb_license
    assert_equal "EQP7605", team.reload.fpb_code
    assert_equal 2, account.players.count
    assert_equal 1, account.teams.count
  end
end
