require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_auctions"

class Game::GuildLeaderboardTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketAuctions

  setup do
    open_market!
    @guilds = Array.new(4) do |number|
      leader = Accounts::Player.create!(steam_id: (76561197962000000 + number).to_s, persona_name: "Leader#{number}")
      fund!(leader, 10_000)
      Game::FoundGuild.new.call(player: leader).value!
    end
  end

  def war(week, guild, opponent, winner) = Game::GuildWar.create!(week_start: week, guild_id: guild.id, opponent_id: opponent&.id, winner_id: winner&.id, ended_at: Time.current)

  test "guilds rank by wars won, then guild money, with draws and defeats counted and ties sharing a rank" do
    first, second, third, fourth = @guilds
    monday = Date.new(2026, 11, 2)
    war(monday, first, second, first)
    war(monday, third, fourth, nil)
    war(monday + 7, first, third, first)
    war(monday + 7, second, fourth, second)
    war(monday + 14, fourth, nil, nil)
    Game::GuildWar.create!(week_start: monday + 21, guild_id: third.id, opponent_id: fourth.id)
    third.update_columns(money: 40)

    rows = Game::GuildLeaderboard.call

    assert_equal [ first, second, third, fourth ], rows.map(&:guild)
    assert_equal [ [ 2, 0, 0 ], [ 1, 0, 1 ], [ 0, 1, 1 ], [ 0, 1, 1 ] ], rows.map { [ it.won, it.drawn, it.lost ] }
    assert_equal [ 1, 2, 3, 4 ], rows.map(&:rank)
    assert_equal [ 1, 1, 1, 1 ], rows.map(&:members)
  end

  test "guilds level on every count share a rank, and a dissolved guild leaves the board" do
    leaver = Accounts::Player.find(@guilds.last.leader_id)
    Game::LeaveGuild.new.call(player: leaver).value!

    rows = Game::GuildLeaderboard.call

    assert_equal 3, rows.size
    assert_equal [ 1, 1, 1 ], rows.map(&:rank)
  end
end
