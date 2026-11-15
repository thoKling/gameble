module Game
  # Pairs guilds listed from most to least active, each with the next one it did not fight last week; an odd one out fights no one.
  module GuildWarPairing
    def self.pairs(guild_ids, last_opponents)
      waiting = guild_ids.dup
      pairs = []
      while (guild_id = waiting.shift)
        opponent = waiting.find { last_opponents[guild_id] != it } || waiting.first
        waiting.delete(opponent)
        pairs << [ guild_id, opponent ]
      end
      pairs
    end
  end
end
