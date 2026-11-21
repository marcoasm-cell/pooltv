class User < ApplicationRecord
  # Roles inside a club. The "admin" flag is separate: a platform admin manages
  # every account, and is only ever set from the console or the seeds.
  ROLES = %w[owner scorer].freeze

  belongs_to :account
  has_many :sessions, dependent: :destroy

  has_secure_password

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }

  # Can configure the club: its owners, and platform admins in any account
  def manager?
    admin? || role == "owner"
  end
end
