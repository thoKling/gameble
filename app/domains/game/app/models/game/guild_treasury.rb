module Game
  # The only writer of guild money: each credit is an entry and the guild's balance moves with it.
  module GuildTreasury
    def self.credit(guild_id:, kind:, amount:, war_id: nil, day: nil)
      raise ArgumentError, "unknown guild money kind: #{kind.inspect}" unless GuildMoneyEntry::KINDS.include?(kind.to_s)
      return unless amount.positive?

      GuildMoneyEntry.create!(guild_id:, kind: kind.to_s, amount:, war_id:, day:)
      Guild.where(id: guild_id).update_all([ "money = money + ?, updated_at = ?", amount, Time.current ])
    end
  end
end
