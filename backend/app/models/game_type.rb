class GameType < ApplicationRecord
  SCORING_MODES = %w[racks points].freeze
  BREAK_RULES = %w[alternate winner loser].freeze

  # Seeded for every account (account_id nil)
  BUILT_IN = [
    { key: "pt_pool", name: "Portuguese Pool", scoring_mode: "racks", default_target: 5, break_rule: "alternate" },
    { key: "8_ball", name: "8-Ball", scoring_mode: "racks", default_target: 5, break_rule: "alternate" },
    { key: "9_ball", name: "9-Ball", scoring_mode: "racks", default_target: 7, break_rule: "alternate" },
    { key: "10_ball", name: "10-Ball", scoring_mode: "racks", default_target: 7, break_rule: "alternate" },
    { key: "blackball", name: "Blackball", scoring_mode: "racks", default_target: 5, break_rule: "alternate" },
    { key: "straight_pool", name: "Straight Pool (14.1)", scoring_mode: "points", default_target: 100, break_rule: "alternate" },
    { key: "one_pocket", name: "One-Pocket", scoring_mode: "racks", default_target: 3, break_rule: "loser" },
    { key: "bank_pool", name: "Bank Pool", scoring_mode: "racks", default_target: 3, break_rule: "loser" }
  ].freeze

  belongs_to :account, optional: true

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :account_id }
  validates :scoring_mode, inclusion: { in: SCORING_MODES }
  validates :break_rule, inclusion: { in: BREAK_RULES }
  validates :default_target, numericality: { greater_than: 0 }

  def built_in?
    account_id.nil?
  end

  def points?
    scoring_mode == "points"
  end

  def self.seed_built_in!
    BUILT_IN.each do |attrs|
      find_or_initialize_by(account_id: nil, key: attrs[:key]).update!(attrs)
    end
  end
end
