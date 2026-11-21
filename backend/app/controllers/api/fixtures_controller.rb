class Api::FixturesController < ApplicationController
  before_action :require_manager!, except: %i[show substitute]
  before_action :set_fixture

  def show
    render json: FixtureSerializer.call(@fixture)
  end

  def walkover
    @fixture.walkover!(params.require(:winner_side))
    render json: FixtureSerializer.call(@fixture.reload)
  end

  # Decider for a team match tied in an elimination round
  def add_rubber
    @fixture.add_rubber!(params[:kind].presence || "singles")
    render json: FixtureSerializer.call(@fixture.reload)
  end

  # Standalone team match: { side, slot (0-based position), player_id }
  def substitute
    @fixture.substitute!(params.require(:side), params.require(:slot), params.require(:player_id))
    render json: FixtureSerializer.call(@fixture.reload)
  end

  private

  def set_fixture
    @fixture = Fixture.joins(:tournament).where(tournaments: { account_id: current_account.id }).find(params[:id])
  end
end
