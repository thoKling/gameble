module Game
  class LeaveGuild < Operation
    def call(player:)
      player = step require_player(player)

      transaction do
        TradeLocks.players(player.id)
        outcome = GuildDeparture.call(player.id)
        step(outcome ? Success() : Failure(:not_in_guild))
        step publish(GuildLeft.new(data: { guild_id: outcome.guild_id, player_id: player.id, dissolved: outcome.dissolved }), stream_name: stream_name(player.id))
        outcome
      end
    end
  end
end
