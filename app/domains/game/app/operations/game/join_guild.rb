module Game
  class JoinGuild < Operation
    def call(player:, code:)
      player = step require_player(player)
      code = step formatted(code)

      transaction do
        TradeLocks.players(player.id)
        step not_in_a_guild(player)
        guild = step guild_of_code(code)
        step seat_free(guild)
        GuildMembership.create!(guild:, player_id: player.id)
        step publish(GuildJoined.new(data: { guild_id: guild.id, player_id: player.id }), stream_name: stream_name(player.id))
        guild
      end
    end

    private

    def formatted(code)
      code = code.to_s.strip.upcase
      FriendCode::FORMAT.match?(code) ? Success(code) : Failure(:invalid_format)
    end

    def not_in_a_guild(player) = GuildMembership.exists?(player_id: player.id) ? Failure(:already_in_guild) : Success()

    def guild_of_code(code)
      guild = Guild.active.lock.find_by(invite_code: code)
      guild ? Success(guild) : Failure(:unknown_guild_code)
    end

    def seat_free(guild) = guild.full? ? Failure(:guild_full) : Success()
  end
end
