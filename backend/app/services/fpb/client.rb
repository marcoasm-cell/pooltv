require "net/http"

module Fpb
  # Reads public data from the Federação Portuguesa de Bilhar portal (portalbilhar.pt).
  #
  # There is no official API: athletes come from the JSON page method behind the
  # public athletes list, and teams and rosters are parsed from the public pages.
  # The parse_* methods are separate so tests can run them on saved HTML.
  class Client
    BASE = "https://www.portalbilhar.pt/Publico/Bt/".freeze
    USER_AGENT = "PoolTV/1.0 (importador de equipas)".freeze

    # Team competitions on the portal: variant => org id used in the page links
    VARIANTS = {
      "Pool_Masculino" => { name: "Pool Masculino", org: 114 },
      "Pool_Feminino" => { name: "Pool Feminino", org: 116 },
      "Pool_Português" => { name: "Pool Português", org: 118 }
    }.freeze

    COMPETITION_FIELD = "ctl00$SampleContent$dd_competicao".freeze
    MAX_PHOTO_BYTES = 5.megabytes

    def self.variants
      VARIANTS.map { |key, v| { key:, name: v[:name] } }
    end

    # All active athletes: [{ license:, name:, full_name:, club:, club_code:, district:, photo: }]
    # About 3500 rows, so it is cached for an hour.
    def athletes
      Rails.cache.fetch("fpb/athletes/v2", expires_in: 1.hour) do
        body = request(:post, "Publico_ListaAtl.aspx/ObterListagemAtletas", json: { filtro: "Activas" }).body
        self.class.parse_athletes(body)
      end
    end

    # Team competitions of a variant: { competitions: [{ code:, name: }], selected: code }
    def competitions(variant)
      self.class.parse_competitions(competition_page(variant).body)
    end

    # Teams entered in a competition: [{ code:, name:, club:, district:, status: }]
    def teams(variant, competition)
      page = competition_page(variant)
      html = page.body
      if competition.present? && self.class.parse_competitions(html)[:selected] != competition
        html = postback(page, COMPETITION_FIELD => competition, "__EVENTTARGET" => COMPETITION_FIELD)
      end
      self.class.parse_teams(html)
    end

    # One team and its roster: { code:, name:, club:, district:, roster: [{ license:, name:, photo: }] }
    def team(code)
      html = request(:get, "Publico_Eqp.aspx?Eqp=#{URI.encode_www_form_component(code)}").body
      self.class.parse_team(html).merge(code:)
    end

    # An athlete's photo, by the file name in the athlete data: the image bytes,
    # or nil when the portal has none
    def photo(file)
      return unless self.class.photo_file(file)

      res = request(:get, "/Imagens/Fotos/#{file}")
      res.body if res.content_type.to_s.start_with?("image/") && res.body.bytesize.between?(1, MAX_PHOTO_BYTES)
    rescue Errors::FpbUnavailable
      nil
    end

    class << self
      def parse_athletes(body)
        rows = JSON.parse(JSON.parse(body).fetch("d").presence || "[]")
        rows.filter_map do |r|
          next if r["Licenca"].blank? || r["Nome"].blank?

          { license: r["Licenca"].to_i, name: clean(r["Nome"]), full_name: clean(r["Nome_Completo"]),
            club: clean(r["Clube"]), club_code: r["Codigo_Clube"], district: clean(r["Distrito"]),
            photo: photo_file(r["Fotografia"]) }
        end
      rescue JSON::ParserError, KeyError
        raise Errors::FpbUnavailable, I18n.t("app_errors.fpb_unreadable")
      end

      def parse_competitions(html)
        doc = Nokogiri::HTML(html)
        options = doc.css("#dd_competicao option")
        { competitions: options.map { |o| { code: o["value"], name: clean(o.text) } },
          selected: options.find { |o| o["selected"] }&.[]("value") || options.first&.[]("value") }
      end

      def parse_teams(html)
        Nokogiri::HTML(html).css("#tbl_inscricao tbody tr").filter_map do |tr|
          cells = tr.css("td")
          link = cells[1]&.at_css("a[href*='Eqp=']")
          next unless link

          { code: link["href"][/Eqp=([^&]+)/, 1], name: clean(link.text), club: clean(cells[0].text),
            status: clean(cells[2]&.text), district: clean(cells[3]&.text) }
        end
      end

      def parse_team(html)
        doc = Nokogiri::HTML(html)
        roster = doc.css("#gv_plantel a[href*='Atl=']").filter_map do |a|
          license = a["href"][/Atl=(\d+)/i, 1]
          next unless license

          img = a.ancestors("tr").first&.at_css("img[src*='Fotos/']")
          { license: license.to_i, name: clean(a.text), photo: photo_file(img&.[]("src")&.split("/")&.last) }
        end
        { name: clean(doc.at_css("#ctl00_SampleContent_lbl_nome")&.text),
          club: clean(doc.at_css("#ctl00_SampleContent_lnk_Equipa")&.text),
          district: clean(doc.at_css("#ctl00_SampleContent_lbl_Distrito")&.text),
          roster: roster.uniq { _1[:license] } }
      end

      # The photo's file name, or nil for none or the portal's placeholder
      def photo_file(file)
        file = file.to_s.strip
        file if file.match?(/\A[\w.-]+\.(png|jpe?g|gif|webp)\z/i) && !file.start_with?("no-photo")
      end

      def clean(text)
        text.to_s.gsub(/[[:space:]]+/, " ").strip.presence
      end
    end

    private

    def competition_page(variant)
      v = VARIANTS.fetch(variant) { raise ArgumentError, I18n.t("app_errors.fpb_unknown_variant") }
      request(:get, "Publico_P_Eqp.aspx?#{URI.encode_www_form(Variante: variant, org: v[:org])}")
    end

    # Submits the page's WebForms form again with some fields changed, like a
    # change of a dropdown in the browser
    def postback(page, changes)
      doc = Nokogiri::HTML(page.body)
      fields = doc.css("form input[type=hidden]").to_h { [ _1["name"], _1["value"].to_s ] }
      doc.css("form select").each do |s|
        fields[s["name"]] = (s.at_css("option[selected]") || s.at_css("option"))&.[]("value").to_s
      end
      cookie = page.get_fields("set-cookie")&.map { _1.split(";").first }&.join("; ")
      request(:post, page.uri.request_uri.delete_prefix("/Publico/Bt/"), form: fields.merge(changes), cookie:).body
    end

    def request(method, path, json: nil, form: nil, cookie: nil)
      uri = URI.join(BASE, path)
      req = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      req["Cookie"] = cookie if cookie
      if json
        req["Content-Type"] = "application/json; charset=utf-8"
        req.body = json.to_json
      elsif form
        req.set_form_data(form)
      end

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) { _1.request(req) }
      unless res.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("FPB request failed: #{method.upcase} #{uri} -> HTTP #{res.code} #{res["location"]}")
        raise Errors::FpbUnavailable, I18n.t("app_errors.fpb_unavailable")
      end

      res.uri ||= uri
      res.body&.force_encoding(Encoding::UTF_8)
      res
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      Rails.logger.warn("FPB request failed: #{e.class}: #{e.message}")
      raise Errors::FpbUnavailable, I18n.t("app_errors.fpb_unavailable")
    end
  end
end
