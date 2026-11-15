module Game
  class FoundGuild < Operation
    ATTEMPTS = 20

    def call(player:)
      player = step require_player(player)

      transaction do
        TradeLocks.players(player.id)
        step not_in_a_guild(player)
        settings = step market_settings
        step afford_fee(player)
        guild = step create_guild(player)
        GuildMembership.create!(guild:, player_id: player.id)
        Market::Ledger.post(fee_entry(player, settings))
        step publish(GuildFounded.new(data: { guild_id: guild.id, player_id: player.id, fee: Guild::FOUNDING_FEE }), stream_name: stream_name(player.id))
        guild
      end
    end

    private

    def not_in_a_guild(player) = GuildMembership.exists?(player_id: player.id) ? Failure(:already_in_guild) : Success()

    def market_settings
      settings = Market::CurrentSettings.call
      settings ? Success(settings) : Failure(:market_pending)
    end

    def afford_fee(player) = Market::Balance.call(player).available >= Guild::FOUNDING_FEE ? Success() : Failure(:guild_fee_unaffordable)

    def create_guild(player)
      ATTEMPTS.times do
        # Postgres aborts the caller's transaction on a unique violation outside a savepoint.
        guild = Guild.transaction(requires_new: true) do
          Guild.create!(**GuildName.random, invite_code: FriendCode.random_code, leader_id: player.id, seats: Guild::STARTING_SEATS)
        end
        return Success(guild)
      rescue ActiveRecord::RecordNotUnique
        next
      end
      Failure(:no_guild_name_left)
    end

    def fee_entry(player, settings)
      Market::Ledger::Entry.new(player_id: player.id, kind: :guild_fee, available_delta: -Guild::FOUNDING_FEE, settings_id: settings.id)
    end
  end
end
