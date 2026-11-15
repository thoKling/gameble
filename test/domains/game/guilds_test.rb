require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_auctions"

class Game::GuildsTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketAuctions

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @dave = Accounts::Player.create!(steam_id: "76561197960900001", persona_name: "Dave")
    open_market!
    fund!(@alice, 12_000)
  end

  def found(player = @alice) = Game::FoundGuild.new.call(player:)
  def join(player, guild) = Game::JoinGuild.new.call(player:, code: guild.invite_code)
  def leave(player) = Game::LeaveGuild.new.call(player:)
  def remove(leader, member) = Game::RemoveGuildMember.new.call(player: leader, member:)
  def members(guild) = Game::GuildMembership.where(guild_id: guild.id).by_seniority.pluck(:player_id)
  def balance(player) = Game::Market::Balance.call(player).available
  def events(type) = Rails.configuration.event_store.read.of_type([ type ]).to_a

  test "founding a guild takes the fee, seats the founder as leader and names the guild" do
    guild = found.value!

    assert_equal 2_000, balance(@alice)
    assert_equal [ @alice.id ], members(guild)
    assert_equal @alice.id, guild.leader_id
    assert_equal 3, guild.seats
    assert_includes Game::GuildName::REGIONS, guild.name_region
    assert_includes Game::GuildName::DIVISIONS, guild.name_division
    assert_match Game::FriendCode::FORMAT, guild.invite_code
    assert_equal [ "guild_fee", -10_000 ], Game::Market::LedgerEntry.where(player_id: @alice.id).order(:id).last.values_at(:kind, :available_delta)
    assert_equal({ guild_id: guild.id, player_id: @alice.id, fee: 10_000 }, events(Game::GuildFounded).sole.data)
  end

  test "the fee counts as destroyed PiCoins, so the market still balances" do
    found.value!

    reconciliation = Game::Market::ReconcileWallets.call
    assert_predicate reconciliation, :balanced?
    assert_equal 10_000, reconciliation.destroyed
  end

  test "a player short of the fee cannot found a guild and keeps their PiCoins" do
    fund!(@bob, 9_999)

    assert_equal :guild_fee_unaffordable, found(@bob).failure
    assert_equal 9_999, balance(@bob)
    assert_equal 0, Game::Guild.count
  end

  test "a guild member cannot found a second guild" do
    found.value!

    assert_equal :already_in_guild, found.failure
    assert_equal 2_000, balance(@alice)
  end

  test "players join with the code, in any case, until the three seats are taken" do
    guild = found.value!

    assert join(@bob, guild).success?
    assert Game::JoinGuild.new.call(player: @carol, code: " #{guild.invite_code.downcase} ").success?
    assert_equal :guild_full, join(@dave, guild).failure
    assert_equal [ @alice.id, @bob.id, @carol.id ], members(guild)
    assert_equal [ @bob.id, @carol.id ], events(Game::GuildJoined).map { it.data[:player_id] }
  end

  test "a code that is malformed or unknown is refused" do
    assert_equal :invalid_format, Game::JoinGuild.new.call(player: @bob, code: "nope").failure
    assert_equal :unknown_guild_code, Game::JoinGuild.new.call(player: @bob, code: "AAAA-BBBB").failure
  end

  test "a player in a guild cannot join another" do
    first = found.value!
    fund!(@bob, 10_000)
    found(@bob).value!

    assert_equal :already_in_guild, join(@bob, first).failure
  end

  test "a leader who leaves hands the guild to the longest-standing member" do
    guild = found.value!
    join(@bob, guild).value!
    join(@carol, guild).value!

    outcome = leave(@alice).value!

    assert_not outcome.dissolved
    assert_equal @bob.id, guild.reload.leader_id
    assert_equal [ @bob.id, @carol.id ], members(guild)
  end

  test "the last member to leave dissolves the guild" do
    guild = found.value!

    assert leave(@alice).value!.dissolved
    assert guild.reload.dissolved_at
    assert_equal :unknown_guild_code, join(@bob, guild).failure
    assert_equal({ guild_id: guild.id, player_id: @alice.id, dissolved: true }, events(Game::GuildLeft).sole.data)
  end

  test "leaving outside a guild fails" do
    assert_equal :not_in_guild, leave(@bob).failure
  end

  test "the leader removes a member, freeing their seat" do
    guild = found.value!
    join(@bob, guild).value!
    join(@carol, guild).value!

    assert_equal @bob, remove(@alice, @bob).value!
    assert_equal [ @alice.id, @carol.id ], members(guild)
    assert join(@dave, guild).success?
  end

  test "only the leader removes, never themselves, and only their own members" do
    guild = found.value!
    join(@bob, guild).value!

    assert_equal :not_guild_leader, remove(@bob, @alice).failure
    assert_equal :cannot_remove_yourself, remove(@alice, @alice).failure
    assert_equal :not_a_guild_member, remove(@alice, @carol).failure
    assert_equal [ @alice.id, @bob.id ], members(guild)
  end

  test "a player dropped with their friends leaves their guild too" do
    guild = found.value!
    join(@bob, guild).value!

    Game::DropFriendsAndTrades.new.call(player: @alice).value!

    assert_equal [ @bob.id ], members(guild)
    assert_equal @bob.id, guild.reload.leader_id
  end

  test "a guild member's page reads the guild with its members by seniority" do
    guild = found.value!
    join(@bob, guild).value!

    result = Game::GuildOf.call(@bob)

    assert_equal guild, result.guild
    assert_equal [ [ @alice, true ], [ @bob, false ] ], result.members.map { [ it.player, it.leader ] }
    assert result.led_by?(@alice)
    assert_nil Game::GuildOf.call(@carol)
  end
end
