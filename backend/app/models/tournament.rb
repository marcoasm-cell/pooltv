class Tournament < ApplicationRecord
  KINDS = %w[individual team].freeze
  FORMATS = %w[single_elimination double_elimination round_robin friendly].freeze
  STATUSES = %w[draft running finished].freeze
  TEAM_WIN_CONDITIONS = %w[rubbers racks].freeze
  RUBBER_KINDS = %w[singles doubles].freeze

  belongs_to :account
  belongs_to :game_type
  has_many :entries, dependent: :destroy
  has_many :fixtures, -> { order(:bracket, :round, :position) }, dependent: :destroy

  before_validation :default_target

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :format, inclusion: { in: FORMATS }
  validates :status, inclusion: { in: STATUSES }
  validates :team_win_condition, inclusion: { in: TEAM_WIN_CONDITIONS }
  validates :target, numericality: { greater_than: 0 }
  validates :team_target, numericality: { greater_than: 0 }, allow_nil: true
  validate :game_type_available
  validate :team_match_format_valid, if: :team?
  validate :pool_tables_valid

  before_validation :normalize_pool_table_ids

  def team?
    kind == "team"
  end

  def draft?
    status == "draft"
  end

  def elimination?
    format.in?(%w[single_elimination double_elimination])
  end

  # Draws are only possible where nobody has to advance
  def draws_allowed?
    !elimination?
  end

  def start!
    raise Errors::InvalidState, I18n.t("app_errors.tournament_started") unless draft?
    raise Errors::InvalidState, I18n.t("app_errors.min_entries") if entries.count < 2
    raise Errors::InvalidState, I18n.t("app_errors.friendly_entries") if format == "friendly" && entries.count != 2

    transaction do
      BracketBuilder.new(self).build!
      update!(status: "running")
    end
  end

  # Back to draft, throwing away every fixture and match
  def reset!
    transaction do
      fixture_ids = fixtures.ids
      match_ids = Match.where(fixture_id: fixture_ids).ids
      PoolTable.where(current_match_id: match_ids).update_all(current_match_id: nil)
      MatchEvent.where(match_id: match_ids).delete_all
      MatchPlayer.where(match_id: match_ids).delete_all
      Match.where(id: match_ids).delete_all
      Fixture.where(id: fixture_ids).update_all(winner_to_id: nil, loser_to_id: nil)
      Fixture.where(id: fixture_ids).delete_all
      update!(status: "draft", ended_early: false)
    end
  end

  # Stops a running tournament now: live matches are abandoned (no winner)
  # and taken off their tables, unplayed matches are dropped and every
  # fixture still open is voided. Results already played are kept.
  def end_early!
    raise Errors::InvalidState, I18n.t("app_errors.tournament_not_running") unless status == "running"

    transaction do
      open = fixtures.where.not(status: %w[finished void]).includes(:matches).to_a
      open.flat_map(&:matches).each do |m|
        if m.live?
          m.update!(status: "finished", winner_side: nil, finished_at: Time.current)
          PoolTable.where(current_match_id: m.id).find_each { |t| t.update!(current_match: nil) }
        elsif m.scheduled?
          PoolTable.where(current_match_id: m.id).find_each { |t| t.update!(current_match: nil) }
          m.destroy!
        end
      end
      open.each { |f| f.update!(status: "void") }
      update!(status: "finished", ended_early: true)
    end
  end

  # Tables chosen for this tournament, in the order they were picked
  def pool_tables
    ids = Array(pool_table_ids)
    return [] if ids.empty?

    account.pool_tables.where(id: ids, active: true).sort_by { |t| ids.index(t.id) }
  end

  # Puts a new match in the queue of the chosen table with the fewest games
  # waiting or being played (the first picked wins a tie). Nothing happens
  # when no tables were chosen or the match already has a table.
  def auto_assign!(match)
    return if match.pool_table_id || !match.scheduled?

    tables = pool_tables
    return if tables.empty?

    waiting = Match.where(pool_table_id: tables.map(&:id), status: %w[scheduled live]).group(:pool_table_id).count
    match.assign_to!(tables.min_by { |t| [ waiting[t.id].to_i, tables.index(t) ] })
  end

  # Gives a table to every unplayed match that has none, e.g. after the
  # tables of a running tournament were changed
  def auto_assign_unplaced!
    Match.where(fixture_id: fixtures.select(:id), status: "scheduled", pool_table_id: nil)
         .order(:fixture_id, :rubber_number, :id).each { |m| auto_assign!(m) }
  end

  def check_finished!
    return unless status == "running"
    return if fixtures.where.not(status: %w[finished void]).exists?

    update!(status: "finished")
  end

  def winner_entry
    return unless status == "finished"
    # Stopped before the final: nobody won the bracket
    return if ended_early && elimination?

    case format
    when "round_robin" then Standings.new(self).rows.first&.dig(:entry)
    else fixtures.reject { |f| f.status == "void" }.max_by { |f| [ f.bracket == "grand_final" ? 1 : 0, f.round ] }&.winner_entry
    end
  end

  private

  def default_target
    self.target ||= game_type&.default_target
  end

  def game_type_available
    return if game_type.nil? || game_type.account_id.nil? || game_type.account_id == account_id

    errors.add(:game_type, :unavailable)
  end

  def normalize_pool_table_ids
    self.pool_table_ids = Array(pool_table_ids).map { |id| Integer(id, exception: false) }.compact.uniq
  end

  def pool_tables_valid
    return if pool_table_ids.empty?
    return if account && account.pool_tables.where(id: pool_table_ids).count == pool_table_ids.size

    errors.add(:pool_table_ids, :other_account)
  end

  def team_match_format_valid
    if !team_match_format.is_a?(Array) || team_match_format.empty?
      errors.add(:team_match_format, :no_rubbers)
    elsif (team_match_format - RUBBER_KINDS).any?
      errors.add(:team_match_format, :bad_rubbers)
    end
  end
end
