module Game
  # Where a guild's war of the week stands, from its own side, and how its last war ended.
  module GuildWarOf
    Side = Data.define(:guild, :points, :roster, :today)
    Standing = Data.define(:war, :own, :rival, :days_settled) do
      def unopposed? = rival.nil?
    end
    Outcome = Data.define(:result, :points, :rival_points, :rival)

    def self.call(guild, now: Time.current)
      war = GuildWar.of_guild(guild.id).find_by(week_start: WeeklyGoal.week_start(now))
      war && standing(war, guild, now.utc.to_date)
    end

    def self.last_outcome(guild, now: Time.current)
      war = GuildWar.of_guild(guild.id).where.not(ended_at: nil).where(week_start: ...WeeklyGoal.week_start(now)).order(week_start: :desc).first
      return unless war

      rival_id = war.other_than(guild.id)
      Outcome.new(result: result_of(war, guild.id), points: war.points_of(guild.id), rival_points: rival_id ? war.points_of(rival_id) : nil,
        rival: rival_id && Guild.find(rival_id))
    end

    def self.standing(war, guild, today)
      rosters = GuildWarMember.where(war_id: war.id).group(:guild_id).count
      today_openings = GuildWarDay.where(war_id: war.id, day: today).pluck(:guild_id, :openings).to_h
      side = ->(side_guild) { Side.new(guild: side_guild, points: war.points_of(side_guild.id), roster: rosters.fetch(side_guild.id, 0), today: today_openings.fetch(side_guild.id, 0)) }
      rival_id = war.other_than(guild.id)
      settled = war.settled_through ? (war.settled_through - war.week_start).to_i + 1 : 0
      Standing.new(war:, own: side.call(guild), rival: rival_id && side.call(Guild.find(rival_id)), days_settled: settled)
    end

    def self.result_of(war, guild_id)
      return :unopposed unless war.opposed?
      return :drawn unless war.winner_id

      war.winner_id == guild_id ? :won : :lost
    end

    private_class_method :standing, :result_of
  end
end
