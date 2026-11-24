# Pushes live state to the overlays and apps over Action Cable.
#   table:<id>   - the OBS overlay of one table
#   account:<id> - the all-tables overlay, the admin and the scoring app
#   public:match:<id>, public:tournament:<id> - the public pages (QR code)
# Payloads are full snapshots, so a client only has to replace what it has.
#
# Inside Broadcaster.batch { ... } nothing is sent until the block ends; then
# every table, match and fixture touched goes out once (e.g. creating a team
# match changes 16 matches on the same tables).
module Broadcaster
  module_function

  def batch
    return yield if Thread.current[:broadcaster_batch]

    Thread.current[:broadcaster_batch] = queue = { table_ids: Set.new, matches: {}, fixtures: {} }
    begin
      yield
    ensure
      Thread.current[:broadcaster_batch] = nil
      flush(queue)
    end
  end

  def table(table)
    return pending[:table_ids] << table.id if pending

    send_table(table)
  end

  def match(match)
    table_ids = [ match.pool_table_id, match.pool_table_id_before_last_save ].compact
    if pending
      pending[:table_ids].merge(table_ids)
      pending[:matches][match.id] = match # a destroyed one only for the tables it was on
      return
    end

    tables = PoolTable.where(id: table_ids).or(PoolTable.where(current_match_id: match.id)).distinct
    tables.each { |t| send_table(t) }
    send_match(match) unless match.destroyed?
  end

  def fixture(fixture)
    return if fixture.destroyed?
    return pending[:fixtures][fixture.id] = fixture if pending

    send_fixture(fixture)
    # Every table playing a rubber shows the team score
    team_tables(fixture).each { |t| send_table(t) } if fixture.tournament.team?
  end

  # Club logo, name or sponsors changed: every overlay of the account
  def branding(account)
    return if account.destroyed?

    payload = { type: "branding", branding: BrandingSerializer.call(account) }
    ActionCable.server.broadcast(account.broadcast_stream, payload)
    account.pool_tables.each { |t| ActionCable.server.broadcast(t.broadcast_stream, payload) }
  end

  def pending
    Thread.current[:broadcaster_batch]
  end

  def flush(queue)
    matches = queue[:matches].values
    live = matches.reject(&:destroyed?)
    Match.preload_for_serializer(live)
    live.each { |m| send_match(m) }
    fixtures = queue[:fixtures].values
    FixtureSerializer.preload(fixtures)
    fixtures.each { |f| send_fixture(f) }

    scope = PoolTable.where(id: queue[:table_ids].to_a)
    scope = scope.or(PoolTable.where(current_match_id: matches.map(&:id))) if matches.any?
    queue[:fixtures].each_value { |f| scope = scope.or(team_tables(f)) if f.tournament.team? }
    scope.distinct.each { |t| send_table(t) }
  end

  def team_tables(fixture)
    PoolTable.where(current_match_id: fixture.matches.select(:id))
  end

  def send_table(table)
    payload = { type: "table", table: TableSerializer.call(table) }
    ActionCable.server.broadcast(table.broadcast_stream, payload)
    ActionCable.server.broadcast("account:#{table.account_id}", payload)
  end

  def send_match(match)
    Match.preload_for_serializer([ match ])
    payload = { type: "match", match: MatchSerializer.call(match) }
    ActionCable.server.broadcast("account:#{match.account_id}", payload)
    # Public pages: the match's own and its tournament's
    ActionCable.server.broadcast(match.public_stream, payload)
    ActionCable.server.broadcast(match.tournament.public_stream, payload) if match.tournament
  end

  def send_fixture(fixture)
    payload = { type: "fixture", fixture: FixtureSerializer.call(fixture) }
    ActionCable.server.broadcast("account:#{fixture.tournament.account_id}", payload)
    ActionCable.server.broadcast(fixture.tournament.public_stream, payload)
  end
end
