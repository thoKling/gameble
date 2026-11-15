module Game
  class PairGuildWars < ApplicationOperation
    STREAM = "Game::GuildWars"

    def call(week_start:)
      transaction do
        ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(hashtext('game_guild_wars_pairing'))")
        step not_yet_paired(week_start)
        guild_ids = step eligible_guilds(week_start)
        wars = GuildWarPairing.pairs(by_activity(guild_ids, week_start - 7), last_opponents(week_start - 7)).map do |guild_id, opponent_id|
          open_war(week_start, guild_id, opponent_id)
        end
        step publish(GuildWarsPaired.new(data: { week_start: week_start.iso8601, war_ids: wars.map(&:id) }), stream_name: STREAM)
        wars
      end
    end

    private

    def not_yet_paired(week_start) = GuildWar.exists?(week_start:) ? Failure(:already_paired) : Success()

    def eligible_guilds(week_start)
      ids = Guild.active.where(created_at: ...week_start.in_time_zone("UTC")).where(id: GuildMembership.select(:guild_id)).order(:id).pluck(:id)
      ids.empty? ? Failure(:no_guilds) : Success(ids)
    end

    def by_activity(guild_ids, previous_week)
      openings = GuildWarDay.joins("JOIN game_guild_wars ON game_guild_wars.id = game_guild_war_days.war_id")
        .where(game_guild_wars: { week_start: previous_week }, guild_id: guild_ids).group(:guild_id).sum(:openings)
      rosters = GuildWarMember.where(week_start: previous_week, guild_id: guild_ids).group(:guild_id).count
      guild_ids.sort_by { |id| [ -(openings.fetch(id, 0).to_r / rosters.fetch(id, 1)), id ] }
    end

    def last_opponents(previous_week)
      GuildWar.where(week_start: previous_week).where.not(opponent_id: nil).pluck(:guild_id, :opponent_id)
        .flat_map { |guild_id, opponent_id| [ [ guild_id, opponent_id ], [ opponent_id, guild_id ] ] }.to_h
    end

    def open_war(week_start, guild_id, opponent_id)
      war = GuildWar.create!(week_start:, guild_id:, opponent_id:)
      now = Time.current
      rows = GuildMembership.where(guild_id: war.guild_ids).pluck(:guild_id, :player_id).map do |member_guild_id, player_id|
        { war_id: war.id, guild_id: member_guild_id, player_id:, week_start:, created_at: now }
      end
      GuildWarMember.insert_all!(rows, record_timestamps: false)
      war
    end
  end
end
