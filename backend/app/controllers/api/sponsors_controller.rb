# Sponsors shown in turn in the header of the OBS overlays. Logos come as
# multipart uploads (field "logo").
class Api::SponsorsController < ApplicationController
  before_action :require_manager!
  before_action :set_sponsor, only: %i[update destroy]

  def index
    render json: sponsors_json
  end

  def create
    sponsor = nil
    Sponsor.transaction do
      position = current_account.sponsors.maximum(:position).to_i + 1
      sponsor = current_account.sponsors.create!(params.permit(:name, :email, :active).with_defaults(position:))
      sponsor.attach_logo!(params[:logo]) if params[:logo].present?
    end
    changed
    render json: sponsors_json, status: :created
  end

  def update
    @sponsor.update!(params.permit(:name, :email, :active))
    @sponsor.attach_logo!(params[:logo]) if params[:logo].present?
    changed
    render json: sponsors_json
  end

  def destroy
    @sponsor.destroy!
    changed
    render json: sponsors_json
  end

  # ids: every sponsor of the account, in the new order
  def order
    ids = Array(params.require(:ids)).map(&:to_i)
    Sponsor.transaction do
      ids.each_with_index { |id, i| current_account.sponsors.find(id).update!(position: i + 1) }
    end
    changed
    render json: sponsors_json
  end

  private

  def set_sponsor
    @sponsor = current_account.sponsors.find(params[:id])
  end

  def changed
    Broadcaster.branding(current_account)
  end

  def sponsors_json
    BrandingSerializer.call(current_account, admin: true)[:sponsors]
  end
end
