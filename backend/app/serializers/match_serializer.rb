# The shape every client renders a match from: overlays, admin and scoring
module MatchSerializer
  module_function

  def call(match, fixture: true)
    data = {
      id: match.id, public_token: match.public_token, name: match.name, status: match.status, kind: match.kind, target: match.target,
      rubber_number: match.rubber_number, breaking_side: match.breaking_side, winner_side: match.winner_side,
      started_at: match.started_at, finished_at: match.finished_at,
      pool_table_id: match.pool_table_id, queue_position: match.queue_position,
      game_type: { key: match.game_type.key, name: match.game_type.name, scoring_mode: match.game_type.scoring_mode },
      home: side(match, "home"), away: side(match, "away"),
      fixture_id: match.fixture_id, tournament: nil, round_label: nil, team_match: nil
    }
    return data unless fixture && match.fixture

    f = match.fixture
    t = f.tournament
    data[:tournament] = { id: t.id, name: t.name, kind: t.kind, format: t.format, public_token: t.public_token }
    data[:round_label] = FixtureSerializer.round_label(f)
    data[:team_match] = team_match(f) if t.team?
    data
  end

  def side(match, side)
    {
      name: match.side_name(side),
      score: match.score(side),
      players: match.side_players(side).map { |p| PlayerSerializer.call(p) }
    }
  end

  def team_match(fixture)
    t = fixture.tournament
    {
      win_condition: t.team_win_condition,
      target: t.team_target,
      rubbers: fixture.matches.size,
      home: team_side(fixture.home_entry, fixture.home_score),
      away: team_side(fixture.away_entry, fixture.away_score)
    }
  end

  def team_side(entry, score)
    team = entry&.team
    { name: team&.name, score: }
  end
end
