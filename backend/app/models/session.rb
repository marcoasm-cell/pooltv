class Session < ApplicationRecord
  belongs_to :user
  # The account a platform admin has switched to; nil means the user's own
  belongs_to :account, optional: true

  has_secure_token :token, length: 36

  def current_account
    (account if user.admin?) || user.account
  end
end
