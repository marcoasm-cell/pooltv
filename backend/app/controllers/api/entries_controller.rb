class Api::EntriesController < ApplicationController
  before_action :require_manager!
  before_action :set_tournament

  # { player_id: } or { team_id: }, optional seed
  def create
    raise Errors::InvalidState, I18n.t("app_errors.entries_before_start") unless @tournament.draft?

    entry = @tournament.entries.create!(
      player: params[:player_id].presence && current_account.players.find(params[:player_id]),
      team: params[:team_id].presence && current_account.teams.find(params[:team_id]),
      seed: params[:seed]
    )
    render json: EntrySerializer.call(entry), status: :created
  end

  def update
    raise Errors::InvalidState, I18n.t("app_errors.seeds_before_start") unless @tournament.draft?

    entry = @tournament.entries.find(params[:id])
    entry.update!(seed: params[:seed])
    render json: EntrySerializer.call(entry)
  end

  def destroy
    raise Errors::InvalidState, I18n.t("app_errors.entries_before_start") unless @tournament.draft?

    @tournament.entries.find(params[:id]).destroy!
    head :no_content
  end

  private

  def set_tournament
    @tournament = current_account.tournaments.find(params[:tournament_id])
  end
end
