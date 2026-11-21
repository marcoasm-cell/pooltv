class Api::GameTypesController < ApplicationController
  before_action :require_manager!, except: :index
  before_action :set_game_type, only: %i[update destroy]

  def index
    render json: current_account.game_types.map { |gt| GameTypeSerializer.call(gt) }
  end

  def create
    gt = current_account.custom_game_types.create!(game_type_params)
    render json: GameTypeSerializer.call(gt), status: :created
  end

  def update
    @game_type.update!(game_type_params)
    render json: GameTypeSerializer.call(@game_type)
  end

  def destroy
    raise Errors::InvalidState, I18n.t("app_errors.game_type_in_use") if Tournament.exists?(game_type: @game_type) || Match.exists?(game_type: @game_type)

    @game_type.destroy!
    head :no_content
  end

  private

  # Built-in game types are shared and read-only
  def set_game_type
    @game_type = current_account.custom_game_types.find(params[:id])
  end

  def game_type_params
    params.permit(:key, :name, :scoring_mode, :default_target, :break_rule, :rules_url)
  end
end
