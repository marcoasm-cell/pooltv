class Api::TournamentsController < ApplicationController
  before_action :require_manager!, except: %i[index show]
  before_action :set_tournament, except: %i[index create]

  def index
    tournaments = current_account.tournaments.includes(:game_type, :entries).order(created_at: :desc)
    tournaments = tournaments.where(status: params[:status]) if params[:status].present?
    # Archived ones only on request (?archived=1)
    tournaments = ActiveModel::Type::Boolean.new.cast(params[:archived]) ? tournaments.where.not(archived_at: nil) : tournaments.where(archived_at: nil)
    render json: tournaments.map { |t| TournamentSerializer.call(t) }
  end

  def show
    render json: TournamentSerializer.call(@tournament, details: true)
  end

  def create
    tournament = current_account.tournaments.create!(tournament_params)
    render json: TournamentSerializer.call(tournament, details: true), status: :created
  end

  def update
    raise Errors::InvalidState, I18n.t("app_errors.only_name_after_start") if !@tournament.draft? && (tournament_params.keys - %w[name starts_on pool_table_ids]).any?

    @tournament.update!(tournament_params)
    @tournament.auto_assign_unplaced! if @tournament.status == "running" && tournament_params.key?(:pool_table_ids)
    render json: TournamentSerializer.call(@tournament, details: true)
  end

  def destroy
    raise Errors::InvalidState, I18n.t("app_errors.reset_before_delete") unless @tournament.draft?

    @tournament.destroy!
    head :no_content
  end

  def start
    @tournament.start!
    render json: TournamentSerializer.call(@tournament.reload, details: true)
  end

  def reset
    raise Errors::InvalidState, I18n.t("app_errors.tournament_match_live") if Match.where(fixture: @tournament.fixtures, status: "live").exists?

    @tournament.reset!
    render json: TournamentSerializer.call(@tournament.reload, details: true)
  end

  # Ends a running tournament now, abandoning whatever is still being played
  def end_early
    @tournament.end_early!
    render json: TournamentSerializer.call(@tournament.reload, details: true)
  end

  def archive
    @tournament.archive!
    render json: TournamentSerializer.call(@tournament, details: true)
  end

  def unarchive
    @tournament.unarchive!
    render json: TournamentSerializer.call(@tournament, details: true)
  end

  private

  def set_tournament
    @tournament = current_account.tournaments.find(params[:id])
  end

  def tournament_params
    permitted = params.permit(:name, :kind, :format, :target, :grand_final_reset, :starts_on,
                              :team_win_condition, :team_target, :game_type_id, team_match_format: [], pool_table_ids: [])
    # An empty list arrives as a missing key; send pool_table_ids: [] to clear
    permitted[:pool_table_ids] = [] if params.key?(:pool_table_ids) && params[:pool_table_ids].blank?
    if permitted[:game_type_id]
      permitted[:game_type_id] = current_account.game_types.find(permitted[:game_type_id]).id
    end
    permitted
  end
end
