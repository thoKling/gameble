module Game
  # Every active guild ranked by wars won, then guild money, then draws; a guild's rank is shared with the guilds tied with it.
  module GuildLeaderboard
    Row = Data.define(:rank, :guild, :members, :won, :drawn, :lost)

    def self.call
      guilds = Guild.active.order(:id).to_a
      members = GuildMembership.where(guild_id: guilds.map(&:id)).group(:guild_id).count
      records = records_of(guilds.map(&:id))
      ranked = guilds.sort_by { |guild| [ -records[guild.id][:won], -guild.money, -records[guild.id][:drawn], guild.id ] }
      ranked.each_with_object([]) do |guild, rows|
        record = records[guild.id]
        previous = rows.last
        tied = previous && [ previous.won, previous.guild.money, previous.drawn ] == [ record[:won], guild.money, record[:drawn] ]
        rows << Row.new(rank: tied ? previous.rank : rows.size + 1, guild:, members: members.fetch(guild.id, 0), **record)
      end
    end

    def self.records_of(guild_ids)
      records = guild_ids.to_h { [ it, { won: 0, drawn: 0, lost: 0 } ] }
      GuildWar.where.not(ended_at: nil).where.not(opponent_id: nil).pluck(:guild_id, :opponent_id, :winner_id).each do |guild_id, opponent_id, winner_id|
        [ guild_id, opponent_id ].each do |side|
          next unless records.key?(side)

          outcome = winner_id.nil? ? :drawn : (winner_id == side ? :won : :lost)
          records[side][outcome] += 1
        end
      end
      records
    end

    private_class_method :records_of
  end
end
