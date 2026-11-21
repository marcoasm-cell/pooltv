# League table of a round robin (or friendly) tournament
class Standings
  POINTS = { win: 3, draw: 1, loss: 0 }.freeze

  def initialize(tournament)
    @tournament = tournament
  end

  def rows
    table = @tournament.entries.includes(FixtureSerializer::ENTRY_PRELOAD).to_h do |e|
      [ e.id, { entry: e, played: 0, won: 0, drawn: 0, lost: 0, score_for: 0, score_against: 0, points: 0 } ]
    end

    @tournament.fixtures.where(status: "finished").each do |f|
      next unless f.home_entry_id && f.away_entry_id

      [ [ f.home_entry_id, f.home_score, f.away_score ], [ f.away_entry_id, f.away_score, f.home_score ] ].each do |id, own, other|
        row = table[id]
        row[:played] += 1
        row[:score_for] += own
        row[:score_against] += other
        result = if f.winner_entry_id.nil? then :draw elsif f.winner_entry_id == id then :win else :loss end
        row[{ win: :won, draw: :drawn, loss: :lost }[result]] += 1
        row[:points] += POINTS[result]
      end
    end

    table.values.sort_by { |r| [ -r[:points], -(r[:score_for] - r[:score_against]), -r[:score_for], r[:entry].display_name.to_s ] }
  end
end
