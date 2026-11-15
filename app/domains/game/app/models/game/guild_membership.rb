module Game
  class GuildMembership < ApplicationRecord
    self.table_name = "game_guild_memberships"

    belongs_to :guild, class_name: "Game::Guild", inverse_of: :memberships

    scope :by_seniority, -> { order(:created_at, :id) }
  end
end
