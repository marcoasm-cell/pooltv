# Public snapshots for OBS overlays; live changes then arrive on OverlayChannel
class Api::OverlaysController < ApplicationController
  skip_before_action :authenticate!

  def table
    table = PoolTable.find_by!(overlay_token: params[:token])
    render json: { account: { name: table.account.name }, branding: BrandingSerializer.call(table.account), table: TableSerializer.call(table) }
  end

  def all
    account = Account.find_by!(overlay_token: params[:token])
    render json: {
      account: { name: account.name },
      branding: BrandingSerializer.call(account),
      overlay: account.overlay_config,
      tables: account.pool_tables.where(active: true).map { |t| TableSerializer.call(t) }
    }
  end
end
