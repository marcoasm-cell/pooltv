# Public, read-only stream for OBS overlays, keyed by the overlay token of a
# table (one table) or of an account (all tables).
class OverlayChannel < ApplicationCable::Channel
  def subscribed
    token = params[:token].to_s
    target = PoolTable.find_by(overlay_token: token) || Account.find_by(overlay_token: token)
    return reject if token.blank? || target.nil?

    stream_from target.broadcast_stream
  end
end
