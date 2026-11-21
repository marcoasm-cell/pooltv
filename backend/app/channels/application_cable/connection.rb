module ApplicationCable
  # Overlays connect without a user (their token goes to the channel); the
  # admin and scoring apps pass their session token as ?token=.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_account

    def connect
      token = request.params[:token]
      session = Session.find_by(token:) if token.present?
      self.current_user = session&.user
      # The account the session looks at (a platform admin may switch)
      self.current_account = session&.current_account
    end
  end
end
