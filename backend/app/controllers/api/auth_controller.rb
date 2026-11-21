# Accounts are created by platform admins (Api::Admin::AccountsController)
class Api::AuthController < ApplicationController
  skip_before_action :authenticate!, only: :login

  def login
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    if user&.authenticate(params[:password].to_s)
      session = user.sessions.create!(user_agent: request.user_agent)
      render json: session_json(session).merge(token: session.token)
    else
      render json: { error: I18n.t("app_errors.wrong_credentials") }, status: :unauthorized
    end
  end

  def logout
    current_session.destroy!
    head :no_content
  end

  def me
    render json: session_json(current_session)
  end
end
