# What the overlays show around the scores: the club's name and logo, and the
# sponsors in turn (logo, name and email, on a card). admin: also the sponsors switched off.
module BrandingSerializer
  module_function

  def call(account, admin: false)
    sponsors = account.sponsors.ordered.with_attached_logo
    sponsors = sponsors.where(active: true) unless admin
    sponsors = sponsors.select { |s| admin || s.logo.attached? }
    {
      name: account.name,
      logo_url: account.logo_path,
      sponsors: sponsors.map do |s|
        data = { id: s.id, name: s.name, email: s.email, logo_url: s.logo_path }
        admin ? data.merge(active: s.active, position: s.position) : data
      end
    }
  end
end
