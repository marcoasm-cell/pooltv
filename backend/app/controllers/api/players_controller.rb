class Api::PlayersController < ApplicationController
  before_action :require_manager!, except: %i[index show]
  before_action :set_player, except: %i[index create]

  def index
    players = current_account.players.with_attached_photo.order(:name)
    players = players.where("name ILIKE :q OR nickname ILIKE :q", q: "%#{Player.sanitize_sql_like(params[:q])}%") if params[:q].present?
    render json: players.map { |p| PlayerSerializer.call(p) }
  end

  def show
    render json: PlayerSerializer.call(@player).merge(teams: @player.teams.map { |t| TeamSerializer.call(t) })
  end

  def create
    render json: PlayerSerializer.call(current_account.players.create!(player_params)), status: :created
  end

  def update
    @player.update!(player_params)
    render json: PlayerSerializer.call(@player)
  end

  def destroy
    @player.destroy || raise(Errors::InvalidState, I18n.t("app_errors.player_in_use"))
    head :no_content
  end

  private

  def set_player
    @player = current_account.players.find(params[:id])
  end

  def player_params
    params.permit(:name, :nickname, :country_code)
  end
end
