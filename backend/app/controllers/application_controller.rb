class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  around_action :switch_locale
  # A write can touch many fixtures and matches (starting a tournament creates
  # them all): send each one out once, when the action is done
  around_action :batch_broadcasts, unless: -> { request.get? || request.head? }
  before_action :authenticate!

  # Rails' own "Couldn't find X" messages are replaced by a translated one
  rescue_from ActiveRecord::RecordNotFound do |e|
    message = e.model ? nil : e.message.presence
    I18n.with_locale(request_locale) do
      render json: { error: message || I18n.t("app_errors.not_found") }, status: :not_found
    end
  end
  rescue_from ActiveRecord::RecordInvalid do |e|
    I18n.with_locale(request_locale) do
      render json: { error: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_content
    end
  end
  rescue_from Errors::InvalidState, ArgumentError do |e|
    render json: { error: e.message }, status: :unprocessable_content
  end
  rescue_from Errors::FpbUnavailable do |e|
    render json: { error: e.message }, status: :bad_gateway
  end
  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: e.message }, status: :bad_request
  end

  private

  attr_reader :current_session

  def batch_broadcasts(&)
    Broadcaster.batch(&)
  end

  def switch_locale(&)
    I18n.with_locale(request_locale, &)
  end

  # First language of Accept-Language we have, matching "pt" to "pt-PT"
  # and "en-GB" to "en"; Portuguese otherwise
  def request_locale
    @request_locale ||= begin
      available = I18n.available_locales.map(&:to_s)
      tags = request.headers["Accept-Language"].to_s.split(",").map { |part| part.split(";").first.to_s.strip }
      match = tags.lazy.filter_map do |tag|
        available.find { |l| l.casecmp?(tag) } || available.find { |l| l.split("-").first.casecmp?(tag.split("-").first) }
      end.first
      (match || I18n.default_locale).to_sym
    end
  end

  def current_user = current_session&.user
  # A platform admin may have switched the session to another account
  def current_account = current_session&.current_account

  def authenticate!
    @current_session = authenticate_with_http_token { |token, _| Session.find_by(token:) }
    return render(json: { error: I18n.t("app_errors.not_signed_in") }, status: :unauthorized) unless @current_session

    @current_session.update_column(:last_used_at, Time.current) if @current_session.last_used_at.nil? || @current_session.last_used_at < 5.minutes.ago
  end

  # Club configuration: the club's owners and platform admins
  def require_manager!
    render json: { error: I18n.t("app_errors.owners_only") }, status: :forbidden unless current_user.manager?
  end

  # Every account: platform admins only
  def require_admin!
    render json: { error: I18n.t("app_errors.admins_only") }, status: :forbidden unless current_user.admin?
  end

  def user_json(user)
    user.slice(:id, :name, :email, :role, :admin, :account_id)
  end

  def session_json(session)
    account = session.current_account
    { user: user_json(session.user), account: { id: account.id, name: account.name } }
  end
end
