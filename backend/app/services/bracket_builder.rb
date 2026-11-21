# Creates the fixtures of a tournament from its entries and places the
# entries in the first round. Byes are given to the top seeds and resolve
# themselves as walkovers.
class BracketBuilder
  def initialize(tournament)
    @tournament = tournament
    seeded, unseeded = tournament.entries.order(:seed, :id).partition(&:seed)
    @entries = seeded + unseeded.shuffle
  end

  def build!
    case @tournament.format
    when "single_elimination" then single_elimination!
    when "double_elimination" then double_elimination!
    when "round_robin" then round_robin!
    when "friendly" then friendly!
    end
  end

  # 1, 2 → 1, 4, 2, 3 → 1, 8, 4, 5, 2, 7, 3, 6: top seeds meet as late as possible
  def self.seed_order(size)
    order = [ 1 ]
    order = order.flat_map { |s| [ s, order.size * 2 + 1 - s ] } while order.size < size
    order
  end

  private

  def bracket_size
    size = 2
    size *= 2 while size < @entries.size
    size
  end

  def fixture(bracket, round, position)
    @tournament.fixtures.create!(bracket:, round:, position:)
  end

  def link(from, kind, to, slot)
    from.update!("#{kind}_to" => to, "#{kind}_to_slot" => slot)
  end

  def slot_for(index)
    index.even? ? "home" : "away"
  end

  # rounds[r] holds the fixtures of round r + 1, winners feeding forward
  def winners_bracket
    rounds = []
    count = bracket_size / 2
    while count >= 1
      rounds << (1..count).map { |p| fixture("winners", rounds.size + 1, p) }
      count /= 2
    end
    rounds.each_cons(2) do |current, following|
      current.each_with_index { |f, i| link(f, :winner, following[i / 2], slot_for(i)) }
    end
    rounds
  end

  def place_first_round(first_round)
    order = self.class.seed_order(bracket_size)
    first_round.each_with_index do |f, i|
      %w[home away].each_with_index do |slot, s|
        entry = @entries[order[i * 2 + s] - 1]
        entry ? f.place!(slot, entry) : f.mark_bye!(slot)
      end
    end
  end

  def single_elimination!
    place_first_round(winners_bracket.first)
  end

  def double_elimination!
    winners = winners_bracket
    k = winners.size
    losers = []

    # Losers round 1 pairs the first-round losers; even rounds take a fresh
    # drop from the winners bracket; odd rounds halve the field.
    count = bracket_size / 4
    (1..2 * (k - 1)).each do |r|
      count /= 2 if r > 1 && r.odd?
      losers << (1..count).map { |p| fixture("losers", r, p) }
    end

    grand_final = fixture("grand_final", 1, 1)
    fixture("grand_final", 2, 1) if @tournament.grand_final_reset

    link(winners.last.first, :winner, grand_final, "home")
    if losers.empty?
      link(winners.last.first, :loser, grand_final, "away")
    else
      winners.first.each_with_index { |f, i| link(f, :loser, losers.first[i / 2], slot_for(i)) }
      winners.drop(1).each_with_index do |round, j|
        target = losers[2 * j + 1]
        # Alternate the drop order so players do not meet again straight away
        round.each_with_index do |f, i|
          link(f, :loser, target[j.even? ? round.size - 1 - i : i], "away")
        end
      end
      losers.each_with_index do |round, r|
        following = losers[r + 1]
        round.each_with_index do |f, i|
          if following.nil? then link(f, :winner, grand_final, "away")
          elsif r.even? then link(f, :winner, following[i], "home")
          else link(f, :winner, following[i / 2], slot_for(i))
          end
        end
      end
    end

    place_first_round(winners.first)
  end

  # Circle method: everyone plays everyone once
  def round_robin!
    list = @entries.dup
    list << nil if list.size.odd?
    n = list.size
    position = 0
    (n - 1).times do |r|
      (n / 2).times do |i|
        home, away = list[i], list[n - 1 - i]
        next unless home && away

        home, away = away, home if i.zero? && r.odd?
        f = fixture("group", r + 1, position += 1)
        f.place!("home", home)
        f.place!("away", away)
      end
      list = [ list.first, list.last, *list[1...-1] ]
    end
  end

  def friendly!
    f = fixture("group", 1, 1)
    f.place!("home", @entries[0])
    f.place!("away", @entries[1])
  end
end
