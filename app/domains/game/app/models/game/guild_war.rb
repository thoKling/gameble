module Game
  class GuildWar < ApplicationRecord
    self.table_name = "game_guild_wars"

    DAYS = 7
    POINTS_PER_DAY = 3
    MONEY = { won: 100, drawn: 50, unopposed: 50 }.freeze

    scope :under_way, -> { where(ended_at: nil) }
    scope :of_guild, ->(guild_id) { where(guild_id:).or(where(opponent_id: guild_id)) }

    def last_day = week_start + (DAYS - 1)
    def opposed? = opponent_id.present?
    def guild_ids = [ guild_id, opponent_id ].compact
    def side_of(guild_id) = guild_id == self.guild_id ? :guild : :opponent
    def points_of(guild_id) = side_of(guild_id) == :guild ? points : opponent_points
    def other_than(guild_id) = side_of(guild_id) == :guild ? opponent_id : self.guild_id
    def fully_settled? = settled_through.present? && settled_through >= last_day
  end
end
