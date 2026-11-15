require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_auctions"

class Game::GuildWarsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include MarketSettings
  include MarketAuctions

  MONDAY = Date.new(2026, 11, 16)

  setup do
    open_market!
    travel_to Time.utc(2026, 11, 13, 12)
    @players = Array.new(5) { |number| Accounts::Player.create!(steam_id: (76561197961000000 + number).to_s, persona_name: "Member#{number}") }
    @players.each { fund!(it, 10_000) }
    @red = found(@players[0], joined: [ @players[1], @players[2] ])
    @blue = found(@players[3], joined: [ @players[4] ])
  end

  teardown { travel_back }

  def found(leader, joined: [])
    Game::FoundGuild.new.call(player: leader).value!.tap do |guild|
      joined.each { Game::JoinGuild.new.call(player: it, code: guild.invite_code).value! }
    end
  end

  def run_at(time) = Game::RunGuildWarsJob.perform_now(now: time)

  def open_packs(player, count, at)
    count.times { Game::GuildWarDay.record_opening(player.id, at) }
  end

  def war = Game::GuildWar.find_by!(week_start: MONDAY)

  test "Monday's run pairs the guilds and freezes their rosters" do
    run_at(Time.utc(2026, 11, 16, 0, 5))

    assert_equal [ @red.id, @blue.id ].sort, war.guild_ids.sort
    assert_equal 5, Game::GuildWarMember.where(war_id: war.id).count
    assert_equal({ @red.id => 3, @blue.id => 2 }, Game::GuildWarMember.where(war_id: war.id).group(:guild_id).count)
  end

  test "a second run the same week pairs nothing more" do
    run_at(Time.utc(2026, 11, 16, 0, 5))
    run_at(Time.utc(2026, 11, 16, 0, 10))

    assert_equal 1, Game::GuildWar.count
  end

  test "each settled day gives 3 points per success to the guild ahead, and guild money per capsule" do
    run_at(Time.utc(2026, 11, 16, 0, 5))
    monday = Time.utc(2026, 11, 16, 10)
    open_packs(@players[0], 9, monday)
    open_packs(@players[3], 8, monday)

    run_at(Time.utc(2026, 11, 17, 0, 5))

    assert_equal MONDAY, war.settled_through
    assert_equal 3, war.points_of(@red.id), "red opened more capsules"
    assert_equal 3, war.points_of(@blue.id), "blue opened more per member: 4 against 3"
    assert_equal 9, @red.reload.money
    assert_equal 8, @blue.reload.money
  end

  test "a day with equal openings and equal averages gives no one points" do
    run_at(Time.utc(2026, 11, 16, 0, 5))

    run_at(Time.utc(2026, 11, 17, 0, 5))

    assert_equal [ 0, 0 ], [ war.points, war.opponent_points ]
  end

  test "after Sunday the war ends: the winner gets its guild money and the next week is paired" do
    run_at(Time.utc(2026, 11, 16, 0, 5))
    open_packs(@players[3], 2, Time.utc(2026, 11, 18, 9))

    run_at(Time.utc(2026, 11, 23, 0, 5))

    ended = war
    assert_equal Date.new(2026, 11, 22), ended.settled_through
    assert_equal @blue.id, ended.winner_id
    assert_equal 6, ended.points_of(@blue.id)
    assert_equal 2 + Game::GuildWar::MONEY[:won], @blue.reload.money
    assert_equal({ war_id: ended.id, winner_id: @blue.id, points: ended.points, opponent_points: ended.opponent_points },
      Rails.configuration.event_store.read.of_type([ Game::GuildWarEnded ]).to_a.sole.data)
    assert Game::GuildWar.exists?(week_start: MONDAY + 7)
  end

  test "a war even on points goes to the higher weekly average, and a perfect tie is a draw" do
    run_at(Time.utc(2026, 11, 16, 0, 5))
    open_packs(@players[0], 6, Time.utc(2026, 11, 16, 9))
    open_packs(@players[3], 5, Time.utc(2026, 11, 16, 9))

    run_at(Time.utc(2026, 11, 23, 0, 5))

    assert_equal [ 3, 3 ], [ war.points_of(@red.id), war.points_of(@blue.id) ]
    assert_equal @blue.id, war.winner_id, "blue averaged 2.5 per member, red 2"
  end

  test "a draw pays both guilds" do
    run_at(Time.utc(2026, 11, 16, 0, 5))

    run_at(Time.utc(2026, 11, 23, 0, 5))

    assert_nil war.winner_id
    assert_equal Game::GuildWar::MONEY[:drawn], @red.reload.money
    assert_equal Game::GuildWar::MONEY[:drawn], @blue.reload.money
  end

  test "an odd guild out has no opponent and is paid for the week" do
    lone = Accounts::Player.create!(steam_id: "76561197961000099", persona_name: "Lone")
    fund!(lone, 10_000)
    green = found(lone)
    run_at(Time.utc(2026, 11, 16, 0, 5))

    assert_equal 2, Game::GuildWar.where(week_start: MONDAY).count
    unopposed = Game::GuildWar.find_by(week_start: MONDAY, opponent_id: nil)
    assert unopposed

    run_at(Time.utc(2026, 11, 23, 0, 5))

    assert_equal Game::GuildWar::MONEY[:unopposed], Game::Guild.find(unopposed.guild_id).money
    assert_includes [ @red.id, @blue.id, green.id ], unopposed.guild_id
  end

  test "a guild founded during the week waits for the next Monday" do
    travel_to Time.utc(2026, 11, 16, 0, 1)
    lone = Accounts::Player.create!(steam_id: "76561197961000098", persona_name: "Late")
    fund!(lone, 10_000)
    late = found(lone)

    run_at(Time.utc(2026, 11, 16, 0, 5))

    assert_not Game::GuildWar.of_guild(late.id).exists?
  end

  test "a member who leaves mid-week still counts for the guild they were rostered with" do
    run_at(Time.utc(2026, 11, 16, 0, 5))
    Game::LeaveGuild.new.call(player: @players[2]).value!

    open_packs(@players[2], 4, Time.utc(2026, 11, 16, 9))

    assert_equal 4, Game::GuildWarDay.find_by(war_id: war.id, guild_id: @red.id).openings
  end

  test "pairing avoids last week's opponent when another guild is free" do
    extra = Array.new(2) { |number| Accounts::Player.create!(steam_id: (76561197961000200 + number).to_s, persona_name: "Extra#{number}") }
    extra.each { fund!(it, 10_000) }
    green = found(extra[0])
    gold = found(extra[1])
    last_week = MONDAY - 7
    Game::GuildWar.create!(week_start: last_week, guild_id: @red.id, opponent_id: @blue.id, ended_at: Time.current)
    Game::GuildWar.create!(week_start: last_week, guild_id: green.id, opponent_id: gold.id, ended_at: Time.current)

    run_at(Time.utc(2026, 11, 16, 0, 5))

    pairs = Game::GuildWar.where(week_start: MONDAY).map { it.guild_ids.sort }
    assert_not_includes pairs, [ @red.id, @blue.id ].sort
    assert_not_includes pairs, [ green.id, gold.id ].sort
  end

  test "the guild page reads the standing from its own side" do
    run_at(Time.utc(2026, 11, 16, 0, 5))
    open_packs(@players[3], 2, Time.utc(2026, 11, 16, 9))
    run_at(Time.utc(2026, 11, 17, 0, 5))
    open_packs(@players[0], 1, Time.utc(2026, 11, 17, 9))

    standing = Game::GuildWarOf.call(@red, now: Time.utc(2026, 11, 17, 10))

    assert_equal [ 0, 6 ], [ standing.own.points, standing.rival.points ]
    assert_equal [ 1, 0 ], [ standing.own.today, standing.rival.today ]
    assert_equal [ 3, 2 ], [ standing.own.roster, standing.rival.roster ]
    assert_equal 1, standing.days_settled
    assert_equal @blue, standing.rival.guild
  end
end
