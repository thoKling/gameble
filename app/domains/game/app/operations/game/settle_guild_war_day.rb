module Game
  class SettleGuildWarDay < ApplicationOperation
    def call(war_id:, day:)
      transaction do
        war = GuildWar.lock.find(war_id)
        step next_day(war, day)
        openings = GuildWarDay.where(war_id:, day:).pluck(:guild_id, :openings).to_h
        war.guild_ids.each { |guild_id| GuildTreasury.credit(guild_id:, kind: :openings, amount: openings.fetch(guild_id, 0), war_id:, day:) }
        points, opponent_points = day_points(war, openings)
        war.update!(points: war.points + points, opponent_points: war.opponent_points + opponent_points, settled_through: day)
        step publish(GuildWarDaySettled.new(data: { war_id:, day: day.iso8601, points: war.points, opponent_points: war.opponent_points }),
          stream_name: "Game::GuildWar$#{war_id}")
        war
      end
    end

    private

    def next_day(war, day)
      expected = war.settled_through ? war.settled_through + 1 : war.week_start
      day == expected && day <= war.last_day ? Success() : Failure(:not_the_next_day)
    end

    def day_points(war, openings)
      return [ 0, 0 ] unless war.opposed?

      rosters = GuildWarMember.where(war_id: war.id).group(:guild_id).count
      GuildWarDayScore.new(openings: openings.fetch(war.guild_id, 0), opponent_openings: openings.fetch(war.opponent_id, 0),
        roster: rosters.fetch(war.guild_id, 0), opponent_roster: rosters.fetch(war.opponent_id, 0)).then { [ it.points, it.opponent_points ] }
    end
  end
end
