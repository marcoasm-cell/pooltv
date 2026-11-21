class Api::PoolTablesController < ApplicationController
  before_action :require_manager!, except: %i[index show]
  before_action :set_table, except: %i[index create]

  def index
    render json: current_account.pool_tables.map { |t| TableSerializer.call(t, admin: current_user.manager?) }
  end

  def show
    queue = @table.queue.to_a
    render json: TableSerializer.call(@table, admin: current_user.manager?, queue:)
              .merge(queue: queue.map { |m| MatchSerializer.call(m) })
  end

  def create
    position = current_account.pool_tables.maximum(:position).to_i + 1
    table = current_account.pool_tables.create!(table_params.with_defaults(position:))
    render json: TableSerializer.call(table, admin: true), status: :created
  end

  def update
    @table.update!(table_params)
    render json: TableSerializer.call(@table, admin: true)
  end

  def destroy
    raise Errors::InvalidState, I18n.t("app_errors.table_busy", table: @table.name) if @table.current_match&.live?

    @table.update!(current_match: nil)
    @table.destroy!
    head :no_content
  end

  # New overlay link; the old one stops working
  def regenerate_token
    @table.regenerate_overlay_token
    render json: TableSerializer.call(@table, admin: true)
  end

  # Takes the finished match off the table so the overlay goes idle
  def clear
    raise Errors::InvalidState, I18n.t("app_errors.table_busy", table: @table.name) if @table.current_match&.live?

    @table.update!(current_match: nil)
    render json: TableSerializer.call(@table, admin: true)
  end

  private

  def set_table
    @table = current_account.pool_tables.find(params[:id])
  end

  def table_params
    permitted = params.permit(:name, :position, :active)
    if params[:overlay_settings].is_a?(ActionController::Parameters)
      permitted[:overlay_settings] = params[:overlay_settings].permit(:visible, *Account::OVERLAY_DEFAULTS.keys).to_h
    end
    permitted
  end
end
