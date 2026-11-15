module Game
  class RemoveGuildMember < Operation
    def call(player:, member:)
      player = step require_player(player)
      step a_player(member)

      transaction do
        TradeLocks.players(player.id, member.id)
        guild = step led_by(player)
        step removable(guild, player, member)
        GuildMembership.where(guild_id: guild.id, player_id: member.id).delete_all
        step publish(GuildMemberRemoved.new(data: { guild_id: guild.id, player_id: player.id, member_id: member.id }), stream_name: stream_name(player.id))
        member
      end
    end

    private

    def a_player(member) = member.is_a?(Accounts::Player) && member.persisted? ? Success() : Failure(:not_a_guild_member)

    def led_by(player)
      guild = Guild.lock.find_by(leader_id: player.id)
      guild ? Success(guild) : Failure(:not_guild_leader)
    end

    def removable(guild, player, member)
      return Failure(:cannot_remove_yourself) if member.id == player.id

      GuildMembership.exists?(guild_id: guild.id, player_id: member.id) ? Success() : Failure(:not_a_guild_member)
    end
  end
end
