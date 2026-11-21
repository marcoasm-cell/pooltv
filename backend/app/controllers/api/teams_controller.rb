class Api::TeamsController < ApplicationController
  before_action :require_manager!, except: %i[index show]
  before_action :set_team, except: %i[index create]

  def index
    render json: current_account.teams.order(:name).includes(team_players: { player: { photo_attachment: :blob } }).map { |t| TeamSerializer.call(t, roster: true) }
  end

  def show
    render json: TeamSerializer.call(@team, roster: true)
  end

  def create
    team = current_account.teams.create!(team_params)
    team.set_roster!(roster_params) if params.key?(:roster)
    render json: TeamSerializer.call(team, roster: true), status: :created
  end

  def update
    @team.update!(team_params)
    render json: TeamSerializer.call(@team, roster: true)
  end

  def destroy
    @team.destroy || raise(Errors::InvalidState, I18n.t("app_errors.team_in_use"))
    head :no_content
  end

  # Replaces the roster: { roster: [{ player_id:, captain: }, ...] }
  def roster
    @team.set_roster!(roster_params)
    render json: TeamSerializer.call(@team.reload, roster: true)
  end

  private

  def set_team
    @team = current_account.teams.find(params[:id])
  end

  def team_params
    params.permit(:name)
  end

  def roster_params
    params.permit(roster: %i[player_id captain]).fetch(:roster, []).map(&:to_h).map(&:symbolize_keys)
  end
end
