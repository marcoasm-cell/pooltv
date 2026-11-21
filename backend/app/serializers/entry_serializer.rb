module EntrySerializer
  module_function

  def call(entry)
    return unless entry

    {
      id: entry.id, seed: entry.seed, name: entry.full_name, display_name: entry.display_name,
      player: entry.player && PlayerSerializer.call(entry.player),
      team: entry.team && TeamSerializer.call(entry.team),
      lineup: lineup(entry)
    }
  end

  # Standalone team match: positions with who started and who plays them now,
  # and the bench (reserves and replaced starters)
  def lineup(entry)
    return if entry.lineup.blank?

    starters, reserves, slots = entry.lineup.values_at("starters", "reserves", "slots")
    players = Player.where(id: starters + reserves).includes(photo_attachment: :blob).index_by(&:id)
    ser = ->(id) { PlayerSerializer.call(players[id]) }
    {
      slots: starters.each_with_index.map { |id, i| { starter: ser.(id), current: ser.(slots[i]) } },
      bench: (starters + reserves - slots).map do |id|
        ser.(id).merge(starter_slot: starters.index(id), reserve: reserves.include?(id))
      end
    }
  end
end
