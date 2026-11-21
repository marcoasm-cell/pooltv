module TableSerializer
  module_function

  # queue: the table's queue already loaded, to avoid querying it again (its
  # matches get preloaded here, together with the current match)
  def call(table, admin: false, queue: nil)
    queue ||= table.queue.limit(1).to_a
    Match.preload_for_serializer([ table.current_match, *queue ])
    up_next = queue.first
    data = {
      id: table.id, name: table.name, position: table.position, active: table.active,
      overlay: table.overlay_config,
      current_match: table.current_match && MatchSerializer.call(table.current_match),
      next_match: up_next && MatchSerializer.call(up_next, fixture: false)
    }
    data[:overlay_token] = table.overlay_token if admin
    data
  end
end
