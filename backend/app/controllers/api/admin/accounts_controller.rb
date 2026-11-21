# Every account (club) on the platform: platform admins only
class Api::Admin::AccountsController < ApplicationController
  before_action :require_admin!
  before_action :set_account, only: %i[update destroy enter]

  def index
    accounts = Account.includes(:users).order(:name)
    render json: accounts.map { |a| account_json(a) }
  end

  # A new club with its first owner
  def create
    account = nil
    Account.transaction do
      account = Account.create!(name: params.require(:name))
      account.users.create!(params.require(:owner).permit(:name, :email, :password).merge(role: "owner"))
    end
    render json: account_json(account), status: :created
  end

  def update
    @account.update!(params.permit(:name))
    Broadcaster.branding(@account)
    render json: account_json(@account)
  end

  def destroy
    raise Errors::InvalidState, I18n.t("app_errors.cannot_remove_own_account") if @account == current_user.account

    @account.destroy!
    head :no_content
  end

  # Switches this session to the account: the whole app then works on it.
  # Entering one's own account goes back to it.
  def enter
    current_session.update!(account: (@account unless @account == current_user.account))
    render json: session_json(current_session)
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def account_json(account)
    owners = account.users.select { _1.role == "owner" }
    {
      id: account.id,
      name: account.name,
      users_count: account.users.size,
      owners: owners.map { _1.slice(:id, :name, :email) },
      created_at: account.created_at
    }
  end
end
