# Public pages where anyone follows a match or a tournament live (the QR code
# on the overlays and the scoring screen). The token is the only key.
class AddPublicTokens < ActiveRecord::Migration[8.1]
  def up
    %i[matches tournaments].each do |table|
      add_column table, :public_token, :string
      select_values("SELECT id FROM #{table}").each do |id|
        execute "UPDATE #{table} SET public_token = #{quote(SecureRandom.base58(24))} WHERE id = #{id.to_i}"
      end
      change_column_null table, :public_token, false
      add_index table, :public_token, unique: true
    end
  end

  def down
    remove_column :matches, :public_token
    remove_column :tournaments, :public_token
  end
end
