# Everything that changes in the account the session looks at
class AccountChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_user

    stream_from current_account.broadcast_stream
  end
end
