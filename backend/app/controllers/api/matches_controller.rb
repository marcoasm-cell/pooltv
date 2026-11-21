# Scorers may play matches (lineup, start, score, undo, finish); setting
# matches up is for admins.
class Api::MatchesController < ApplicationController
  before_action :require_manager!, only: %i[create update destroy assign]
  before_action :set_match, except: %i[index create]

  def index
    matches = current_account.matches.includes(:game_type, match_players: :player, fixture: :tournament)
    matches = matches.where(status: params[:status].split(",")) if params[:status].present?
    matches = matches.where(pool_table_id: params[:pool_table_id]) if params.key?(:pool_table_id)
    matches = matches.where(fixture_id: Fixture.where(tournament_id: params[:tournament_id]).select(:id)) if params[:tournament_id].present?
    render json: matches.order(:queue_position, :id).limit(500).map { |m| MatchSerializer.call(m) }
  end

  def show
    render json: MatchSerializer.call(@match)
  end

  # Match outside any tournament.
  # Both take an optional name, shown on the overlay.
  #   Players: { game_type_id, target, kind, home: [ids], away: [ids], pool_table_id }
  #   Teams:   { game_type_id, race_to, kind: "team", home_team_id, away_team_id,
  #              home_order: [ids], away_order: [ids],
  #              home_reserves: [ids], away_reserves: [ids], pool_table_ids: [ids] }
  # A team match answers with the tournament that holds its rubbers.
  def create
    game_type = current_account.game_types.find(params.require(:game_type_id))
    return create_team_match(game_type) if params[:kind] == "team"

    match = Match.transaction do
      m = current_account.matches.create!(game_type:, target: params[:target].presence || game_type.default_target,
                                          kind: params[:kind].presence || "singles", name: params[:name].to_s.strip.presence)
      m.set_lineup!(home: params[:home], away: params[:away])
      m.assign_to!(current_account.pool_tables.find(params[:pool_table_id])) if params[:pool_table_id].present?
      m
    end
    render json: MatchSerializer.call(match), status: :created
  end

  def update
    raise Errors::InvalidState, I18n.t("app_errors.only_scheduled_change") unless @match.scheduled?

    @match.update!(params.permit(:target, :breaking_side, :queue_position))
    render json: MatchSerializer.call(@match)
  end

  def destroy
    raise Errors::InvalidState, I18n.t("app_errors.tournament_match_delete") if @match.fixture
    raise Errors::InvalidState, I18n.t("app_errors.live_match_delete") if @match.live?

    PoolTable.where(current_match_id: @match.id).update_all(current_match_id: nil)
    @match.destroy!
    head :no_content
  end

  def lineup
    if @match.fixture&.home_entry&.lineup.present?
      raise Errors::InvalidState, I18n.t("app_errors.lineup_by_substitution")
    end

    @match.set_lineup!(home: params[:home], away: params[:away])
    render json: MatchSerializer.call(@match)
  end

  def assign
    table = params[:pool_table_id].presence && current_account.pool_tables.find(params[:pool_table_id])
    @match.assign_to!(table)
    render json: MatchSerializer.call(@match)
  end

  def start
    table = params[:pool_table_id].present? ? current_account.pool_tables.find(params[:pool_table_id]) : @match.pool_table
    @match.start!(table:, breaking_side: params[:breaking_side].presence || @match.breaking_side)
    render json: MatchSerializer.call(@match)
  end

  # { side: "home"|"away", points: n } (points only for points games)
  def score
    @match.score!(params.require(:side), points: params[:points] || 1, user: current_user)
    render json: MatchSerializer.call(@match)
  end

  def undo
    @match.undo!
    render json: MatchSerializer.call(@match)
  end

  # Concession or referee decision
  def finish
    @match.finish!(params.require(:winner_side))
    render json: MatchSerializer.call(@match)
  end

  private

  def create_team_match(game_type)
    tournament = TeamMatchBuilder.new(
      current_account,
      game_type:,
      race_to: params.require(:race_to),
      home_team: current_account.teams.find(params.require(:home_team_id)),
      away_team: current_account.teams.find(params.require(:away_team_id)),
      home_order: params[:home_order], away_order: params[:away_order],
      home_reserves: params[:home_reserves], away_reserves: params[:away_reserves],
      pool_tables: team_match_tables, name: params[:name]
    ).build!
    render json: TournamentSerializer.call(tournament.reload, details: true), status: :created
  end

  # Tables in the order given; pool_table_id alone also works
  def team_match_tables
    ids = Array(params[:pool_table_ids].presence || params[:pool_table_id].presence).map(&:to_i)
    tables = current_account.pool_tables.where(id: ids).index_by(&:id)
    raise ActiveRecord::RecordNotFound, I18n.t("app_errors.unknown_table") if tables.size != ids.uniq.size

    ids.uniq.map { |id| tables[id] }
  end

  def set_match
    @match = current_account.matches.find(params[:id])
  end
end
