module Game
  class Guild < ApplicationRecord
    self.table_name = "game_guilds"

    FOUNDING_FEE = 10_000
    STARTING_SEATS = 3

    has_secure_token :token, length: 24
    has_many :memberships, class_name: "Game::GuildMembership", inverse_of: :guild

    scope :active, -> { where(dissolved_at: nil) }

    def full? = memberships.count >= seats
  end
end
