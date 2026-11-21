class CreateAccountsAndUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      # Secret key of the "all tables" OBS overlay link
      t.string :overlay_token, null: false, index: { unique: true }
      # Overlay look and behaviour: idle mode, layout, winner banner seconds, ...
      t.jsonb :overlay_settings, null: false, default: {}
      t.timestamps
    end

    create_table :users do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false, index: { unique: true }
      t.string :password_digest, null: false
      # owner / admin can configure everything, scorer can only score matches
      t.string :role, null: false, default: "admin"
      t.timestamps
    end

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false, index: { unique: true }
      t.string :user_agent
      t.datetime :last_used_at
      t.timestamps
    end
  end
end
