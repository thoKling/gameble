module Game
  class GuildWarDay < ApplicationRecord
    self.table_name = "game_guild_war_days"

    def self.record_opening(player_id, now)
      stamp = now.utc
      member = GuildWarMember.find_by(player_id:, week_start: WeeklyGoal.week_start(stamp))
      return unless member

      upsert({ war_id: member.war_id, guild_id: member.guild_id, day: stamp.to_date, openings: 1, created_at: stamp, updated_at: stamp },
        unique_by: %i[war_id guild_id day], record_timestamps: false,
        on_duplicate: Arel.sql("openings = game_guild_war_days.openings + 1, updated_at = excluded.updated_at"))
    end
  end
end
