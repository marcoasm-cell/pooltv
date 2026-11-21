class Api::AccountsController < ApplicationController
  before_action :require_manager!, except: :show

  def show
    render json: account_json
  end

  def update
    attrs = params.permit(:name)
    if params[:overlay_settings].is_a?(ActionController::Parameters)
      settings = params[:overlay_settings].permit(*Account::OVERLAY_DEFAULTS.keys).to_h
      attrs[:overlay_settings] = current_account.overlay_settings.merge(settings)
    end
    current_account.update!(attrs)
    current_account.pool_tables.each(&:broadcast)
    # The all-tables overlay reloads its settings on a branding message
    Broadcaster.branding(current_account)
    render json: account_json
  end

  # The club's logo for the overlays: multipart upload, field "logo"
  def logo
    current_account.attach_logo!(params.require(:logo))
    Broadcaster.branding(current_account)
    render json: account_json
  end

  def remove_logo
    current_account.logo.purge_later
    Broadcaster.branding(current_account.reload)
    render json: account_json
  end

  def regenerate_overlay_token
    current_account.regenerate_overlay_token
    render json: account_json
  end

  private

  def account_json
    a = current_account
    { id: a.id, name: a.name, logo_url: a.logo_path, overlay_settings: a.overlay_config, overlay_token: (a.overlay_token if current_user.manager?) }
  end
end
