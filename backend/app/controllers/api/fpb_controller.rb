# Import of teams and players from the Federação Portuguesa de Bilhar portal.
# Browsing (variants, competitions, teams, athletes) reads the portal live;
# import and sync copy the data into the account.
class Api::FpbController < ApplicationController
  before_action :require_manager!

  def variants
    render json: Fpb::Client.variants
  end

  def competitions
    render json: client.competitions(params.require(:variant))
  end

  # Teams of a competition, with the local team each one is already linked to
  def teams
    teams = client.teams(params.require(:variant), params[:competition])
    linked = current_account.teams.where(fpb_code: teams.pluck(:code)).pluck(:fpb_code, :id).to_h
    render json: teams.map { _1.merge(team_id: linked[_1[:code]]) }
  end

  # Search of active athletes by name, licence or club (at most 50)
  def athletes
    q = I18n.transliterate(params[:q].to_s.strip).downcase
    return render(json: []) if q.length < 2

    found = client.athletes.select do |a|
      a[:license].to_s == q || I18n.transliterate("#{a[:name]} #{a[:full_name]} #{a[:club]}").downcase.include?(q)
    end.first(50)
    linked = current_account.players.where(fpb_license: found.pluck(:license)).pluck(:fpb_license, :id).to_h
    render json: found.map { _1.merge(player_id: linked[_1[:license]]) }
  end

  # { teams: ["EQP7605", ...], licenses: [8796, ...] }
  def import
    render json: Fpb::Importer.new(current_account, client:).import(team_codes: params[:teams], licenses: params[:licenses])
  end

  def sync
    render json: Fpb::Importer.new(current_account, client:).sync
  end

  private

  def client = @client ||= Fpb::Client.new
end
