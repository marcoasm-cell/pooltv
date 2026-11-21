class Api::UsersController < ApplicationController
  before_action :require_manager!
  before_action :set_user, only: %i[update destroy]

  def index
    render json: current_account.users.order(:name).map { |u| user_json(u) }
  end

  def create
    user = current_account.users.create!(user_params)
    render json: user_json(user), status: :created
  end

  def update
    @user.update!(user_params.compact_blank)
    render json: user_json(@user)
  end

  def destroy
    raise Errors::InvalidState, I18n.t("app_errors.cannot_remove_self") if @user == current_user

    @user.destroy!
    head :no_content
  end

  private

  # A club's owners cannot touch a platform admin who belongs to their club
  def set_user
    @user = current_account.users.find(params[:id])
    raise Errors::InvalidState, I18n.t("app_errors.admin_user_locked") if @user.admin? && !current_user.admin?
  end

  # The admin flag is never set here: only from the console or the seeds
  def user_params
    params.permit(:name, :email, :password, :role)
  end
end
