class Team < ApplicationRecord
  belongs_to :account
  has_many :team_players, -> { order(:position, :id) }, dependent: :destroy
  has_many :players, through: :team_players
  has_many :entries, dependent: :restrict_with_error

  validates :name, presence: true

  def display_name = name

  # Replaces the roster with [{player_id:, captain:}, ...] in the given order
  def set_roster!(rows)
    transaction do
      ids = rows.map { |r| r[:player_id].to_i }
      players = account.players.where(id: ids).index_by(&:id)
      raise ActiveRecord::RecordNotFound, I18n.t("app_errors.unknown_player") if players.size != ids.uniq.size

      team_players.where.not(player_id: ids).destroy_all
      rows.each_with_index do |row, i|
        tp = team_players.find_or_initialize_by(player_id: row[:player_id].to_i)
        tp.update!(position: i, captain: ActiveModel::Type::Boolean.new.cast(row[:captain]) || false)
      end
    end
  end
end
