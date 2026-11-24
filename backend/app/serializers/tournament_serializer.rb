module TournamentSerializer
  module_function

  def call(t, details: false)
    data = t.slice(:id, :name, :kind, :format, :target, :status, :starts_on, :grand_final_reset,
                   :team_match_format, :team_win_condition, :team_target, :ended_early, :pool_table_ids, :public_token, :archived_at)
    data[:game_type] = GameTypeSerializer.call(t.game_type)
    data[:entries_count] = t.entries.size
    return data unless details

    data[:entries] = t.entries.includes(FixtureSerializer::ENTRY_PRELOAD).order(:seed, :id).map { |e| EntrySerializer.call(e) }
    # Every fixture points at t, whose bracket round_label reads
    fixtures = t.fixtures.to_a
    fixtures.each { |f| f.association(:tournament).target = t }
    data[:fixtures] = FixtureSerializer.preload(fixtures).map { |f| FixtureSerializer.call(f) }
    data[:winner] = EntrySerializer.call(t.winner_entry)
    if t.format.in?(%w[round_robin friendly])
      data[:standings] = Standings.new(t).rows.map { |r| r.merge(entry: EntrySerializer.call(r[:entry])) }
    end
    data
  end
end
