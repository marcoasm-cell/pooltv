GameType.seed_built_in!

if Rails.env.development?
  account = Account.find_or_create_by!(name: "Demo Pool Hall")

  # Platform admin: manages every account
  User.find_or_create_by!(email: "admin@example.com") do |user|
    user.account = account
    user.name = "Admin"
    user.role = "owner"
    user.password = "password"
  end.update!(admin: true)


  User.find_or_create_by!(email: "owner@example.com") do |user|
    user.account = account
    user.name = "owner"
    user.role = "owner"
    user.password = "password"
  end
  User.find_or_create_by!(email: "scorer@example.com") do |user|
    user.account = account
    user.name = "scorer"
    user.role = "scorer"
    user.password = "password"
  end

end
