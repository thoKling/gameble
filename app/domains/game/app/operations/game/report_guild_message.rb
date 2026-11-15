module Game
  class ReportGuildMessage < Operation
    def call(player:, token:)
      player = step require_player(player)

      transaction do
        message = step reportable(player, token)
        message.update!(reported_at: Time.current, reporter_id: player.id)
        step publish(GuildMessageReported.new(data: { message_id: message.id, reporter_id: player.id }), stream_name: stream_name(player.id))
        message
      end
    end

    private

    def reportable(player, token)
      guild_id = GuildMembership.where(player_id: player.id).pick(:guild_id)
      message = token.is_a?(String) && guild_id ? GuildMessage.lock.find_by(token:, guild_id:) : nil
      return Failure(:message_not_found) unless message
      return Failure(:own_message) if message.player_id == player.id

      message.reported_at ? Failure(:already_reported) : Success(message)
    end
  end
end
