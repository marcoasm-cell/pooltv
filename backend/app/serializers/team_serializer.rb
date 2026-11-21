module TeamSerializer
  module_function

  def call(team, roster: false)
    data = { id: team.id, name: team.name, display_name: team.display_name,
             fpb_code: team.fpb_code, fpb_club: team.fpb_club }
    return data unless roster

    data.merge(roster: team.team_players.includes(:player).map do |tp|
      PlayerSerializer.call(tp.player).merge(captain: tp.captain)
    end)
  end
end
