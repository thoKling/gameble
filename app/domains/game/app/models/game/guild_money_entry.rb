module Game
  # One movement of guild money, kept for good.
  class GuildMoneyEntry < ApplicationRecord
    self.table_name = "game_guild_money_entries"

    KINDS = %w[openings war_won war_drawn war_unopposed].freeze

    def readonly? = persisted?
  end
end
