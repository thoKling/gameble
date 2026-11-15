module Game
  # The latest messages of a guild, oldest first, each with its author.
  module GuildMessagesOf
    Line = Data.define(:message, :author)

    def self.call(guild_id)
      messages = GuildMessage.where(guild_id:).order(created_at: :desc, id: :desc).limit(GuildMessage::SHOWN).to_a.reverse
      authors = Accounts::Player.where(id: messages.map(&:player_id).uniq).index_by(&:id)
      messages.map { Line.new(message: it, author: authors[it.player_id]) }
    end
  end
end
