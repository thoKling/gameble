module Game
  # The guild a player belongs to, with its members by seniority; nil outside a guild.
  module GuildOf
    Member = Data.define(:player, :leader, :joined_at)
    Result = Data.define(:guild, :members) do
      def seats_taken = members.size
      def led_by?(player) = guild.leader_id == player.id
    end

    def self.call(player)
      return nil unless player

      guild_id = GuildMembership.where(player_id: player.id).pick(:guild_id)
      guild = guild_id && Guild.find_by(id: guild_id)
      return nil unless guild

      memberships = guild.memberships.by_seniority.to_a
      players = Accounts::Player.where(id: memberships.map(&:player_id)).index_by(&:id)
      members = memberships.filter_map do |membership|
        player = players[membership.player_id]
        Member.new(player:, leader: membership.player_id == guild.leader_id, joined_at: membership.created_at) if player
      end
      Result.new(guild:, members:)
    end
  end
end
