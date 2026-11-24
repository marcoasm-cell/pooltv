# Public pages where anyone follows a match or a tournament (the QR code on the
# overlays and the scoring screen). Read only; the token is the only key. Live
# changes then arrive on PublicChannel.
class Api::PublicController < ApplicationController
  skip_before_action :authenticate!

  def match
    match = Match.find_by!(public_token: params[:token])
    Match.preload_for_serializer([ match ])
    render json: {
      branding: BrandingSerializer.call(match.account),
      tables: tables(match.account),
      match: MatchSerializer.call(match)
    }
  end

  def tournament
    tournament = Tournament.find_by!(public_token: params[:token])
    render json: {
      branding: BrandingSerializer.call(tournament.account),
      tables: tables(tournament.account),
      tournament: TournamentSerializer.call(tournament, details: true)
    }
  end

  private

  # Names of the tables, to say where a match is played
  def tables(account)
    account.pool_tables.map { |t| { id: t.id, name: t.name } }
  end
end
