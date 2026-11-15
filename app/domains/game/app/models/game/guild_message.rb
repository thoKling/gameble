module Game
  class GuildMessage < ApplicationRecord
    self.table_name = "game_guild_messages"

    MAX_LENGTH = 500
    SHOWN = 50

    has_secure_token :token, length: 24

    scope :awaiting_moderation, -> { where.not(reported_at: nil).where(hidden_at: nil) }

    def hidden? = hidden_at.present?
  end
end
