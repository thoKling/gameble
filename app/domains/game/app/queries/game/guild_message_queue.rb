module Game
  # The reported guild messages no moderator has settled yet, oldest report first.
  module GuildMessageQueue
    Row = Data.define(:message, :author, :reporter, :guild)

    def self.call
      messages = GuildMessage.awaiting_moderation.order(:reported_at, :id).to_a
      players = Accounts::Player.where(id: messages.flat_map { [ it.player_id, it.reporter_id ] }.uniq).index_by(&:id)
      guilds = Guild.where(id: messages.map(&:guild_id).uniq).index_by(&:id)
      messages.map { Row.new(message: it, author: players[it.player_id], reporter: players[it.reporter_id], guild: guilds[it.guild_id]) }
    end
  end
end
