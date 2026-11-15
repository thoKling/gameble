module Game
  # A guild's name is a region and a division the Brotherhood assigns; each pair is translated and used once.
  module GuildName
    REGIONS = %w[north south east west central overseas alpine coastal continental upper lower metropolitan].freeze
    DIVISIONS = %w[synergies leisure_assets strategic_luck capsule_logistics perseverance archive_recovery
      wellbeing growth collector_relations prestige].freeze

    def self.random = { name_region: REGIONS.sample(random: SecureRandom), name_division: DIVISIONS.sample(random: SecureRandom) }
  end
end
