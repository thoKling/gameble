module Game
  class RunGuildWarsJob < ActiveJob::Base
    queue_as :default

    def perform(now: Time.current)
      today = now.utc.to_date
      GuildWar.under_way.order(:id).each do |war|
        settle_days(war, today)
        EndGuildWar.new.call(war_id: war.id, now:) if war.reload.fully_settled?
      end
      PairGuildWars.new.call(week_start: WeeklyGoal.week_start(now))
    end

    private

    def settle_days(war, today)
      day = war.settled_through ? war.settled_through + 1 : war.week_start
      while day < today && day <= war.last_day
        SettleGuildWarDay.new.call(war_id: war.id, day:)
        day += 1
      end
    end
  end
end
