module Game
  class PostGuildMessage < Operation
    def call(player:, body:)
      player = step require_player(player)
      body = step written(body)

      transaction do
        guild_id = step guild_of(player)
        message = GuildMessage.create!(guild_id:, player_id: player.id, body:)
        step publish(GuildMessagePosted.new(data: { message_id: message.id, guild_id:, player_id: player.id }), stream_name: stream_name(player.id))
        message
      end
    end

    private

    def written(body)
      text = body.to_s.strip
      return Failure(:message_empty) if text.empty?

      text.length > GuildMessage::MAX_LENGTH ? Failure(:message_too_long) : Success(text)
    end

    def guild_of(player)
      guild_id = GuildMembership.where(player_id: player.id).pick(:guild_id)
      guild_id ? Success(guild_id) : Failure(:not_in_guild)
    end
  end
end
