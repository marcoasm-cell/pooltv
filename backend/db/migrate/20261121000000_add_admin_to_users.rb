# Platform admins: the "admin" flag gives access to every account. Inside a
# club the roles are now only "owner" and "scorer"; club admins become owners.
# A session can look at another account than the user's own (admins only).
class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :admin, :boolean, null: false, default: false
    execute "UPDATE users SET role = 'owner' WHERE role = 'admin'"
    change_column_default :users, :role, from: "admin", to: "scorer"

    add_reference :sessions, :account, foreign_key: { on_delete: :nullify }
  end

  def down
    remove_reference :sessions, :account, foreign_key: true
    change_column_default :users, :role, from: "scorer", to: "admin"
    remove_column :users, :admin
  end
end
