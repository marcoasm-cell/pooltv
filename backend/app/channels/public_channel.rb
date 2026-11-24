# Public, read-only stream of the pages where anyone follows a match or a
# tournament (reached by the QR code), keyed by its public token.
class PublicChannel < ApplicationCable::Channel
  def subscribed
    token = params[:token].to_s
    target =
      case params[:kind]
      when "match" then Match.find_by(public_token: token)
      when "tournament" then Tournament.find_by(public_token: token)
      end
    return reject if token.blank? || target.nil?

    stream_from target.public_stream
  end
end
