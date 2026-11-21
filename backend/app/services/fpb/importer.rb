module Fpb
  # Copies FPB teams, rosters and athletes into an account.
  #
  # Records are matched by FPB id (licence / team code), or else by an exact name
  # among the records not yet linked to the FPB, so players created by hand are
  # linked instead of copied. Importing again updates names and adds new roster
  # players; it never removes players or teams.
  #
  # Photos are downloaded afterwards by FpbPhotosJob, and only when the photo's
  # file name on the portal changed.
  class Importer
    MAX_TEAMS = 40

    Result = Struct.new(:players_created, :players_updated, :teams_created, :teams_updated, :roster_added, :photos_queued) do
      def initialize = super(0, 0, 0, 0, 0, 0)
    end

    # [[player_id, file], ...] => attaches each photo and records its file name
    def self.download_photos(pairs, client: Client.new)
      pairs.each do |player_id, file|
        player = Player.find_by(id: player_id)
        next if player.nil? || player.fpb_photo == file

        bytes = client.photo(file) or next
        player.photo.attach(io: StringIO.new(bytes), filename: file)
        player.update!(fpb_photo: file)
      end
    end

    def initialize(account, client: Client.new)
      @account = account
      @client = client
      @result = Result.new
      @photos = {}
      @queued = Set.new # players whose photo is already queued by this importer
    end

    # team_codes: ["EQP7605", ...]; licenses: [8796, ...] for athletes without a team
    def import(team_codes: [], licenses: [])
      team_codes = Array(team_codes).map(&:to_s).compact_blank.uniq
      raise ArgumentError, "At most #{MAX_TEAMS} teams at a time" if team_codes.size > MAX_TEAMS

      # Fetch everything first so a failure halfway leaves the account unchanged
      teams = team_codes.map { @client.team(_1) }
      athletes = athletes_for(licenses)

      ActiveRecord::Base.transaction do
        athletes.each { upsert_player(_1) }
        teams.each { upsert_team(_1) }
      end
      queue_photos
      @result.to_h
    end

    # Updates every team and player that came from the FPB
    def sync
      codes = @account.teams.where.not(fpb_code: nil).pluck(:fpb_code)
      licenses = @account.players.where.not(fpb_license: nil).pluck(:fpb_license)
      codes.each_slice(MAX_TEAMS) { import(team_codes: _1) }
      import(licenses:) # the counts add up over the calls
    end

    private

    def athletes_for(licenses)
      licenses = Array(licenses).map(&:to_i).select(&:positive?).uniq
      return [] if licenses.empty?

      @client.athletes.select { licenses.include?(_1[:license]) }
    end

    def upsert_player(data)
      player = @account.players.find_by(fpb_license: data[:license]) ||
        @account.players.where(fpb_license: nil).where("LOWER(name) = LOWER(?)", data[:name]).first ||
        @account.players.new(fpb_license: data[:license], country_code: "PT")

      player.assign_attributes(fpb_license: data[:license], name: data[:name])
      player.fpb_club = data[:club] if data[:club]
      count(player, :players)
      player.save! if player.changed?
      if data[:photo] && data[:photo] != player.fpb_photo && !@queued.include?(player.id)
        @photos[player.id] = data[:photo]
      end
      player
    end

    def queue_photos
      return if @photos.empty?

      FpbPhotosJob.perform_later(@photos.to_a)
      @result.photos_queued += @photos.size
      @queued.merge(@photos.keys)
      @photos = {}
    end

    def upsert_team(data)
      team = @account.teams.find_by(fpb_code: data[:code]) ||
        @account.teams.where(fpb_code: nil).where("LOWER(name) = LOWER(?)", data[:name]).first ||
        @account.teams.new
      team.assign_attributes(fpb_code: data[:code], name: data[:name] || data[:code], fpb_club: data[:club])
      count(team, :teams)
      team.save! if team.changed?

      position = team.team_players.maximum(:position).to_i
      data[:roster].each do |athlete|
        player = upsert_player(athlete.merge(club: data[:club]))
        next if team.team_players.exists?(player_id: player.id)

        team.team_players.create!(player:, position: position += 1)
        @result.roster_added += 1
      end
    end

    def count(record, kind)
      if record.new_record?
        @result["#{kind}_created"] += 1
      elsif record.changed?
        @result["#{kind}_updated"] += 1
      end
    end
  end
end
