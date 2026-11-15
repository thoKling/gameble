module Game
  # Takes a player out of their guild: a departing leader hands over to the longest-standing member, and a guild left empty is dissolved.
  module GuildDeparture
    Outcome = Data.define(:guild_id, :dissolved)

    def self.call(player_id, now: Time.current)
      guild_id = GuildMembership.where(player_id:).pick(:guild_id)
      return unless guild_id

      guild = Guild.lock.find(guild_id)
      return unless GuildMembership.where(player_id:, guild_id:).delete_all.positive?

      successor = guild.memberships.by_seniority.pick(:player_id)
      if successor.nil?
        guild.update!(dissolved_at: now)
      elsif guild.leader_id == player_id
        guild.update!(leader_id: successor)
      end
      Outcome.new(guild_id:, dissolved: successor.nil?)
    end
  end
end
