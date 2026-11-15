require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_auctions"

class Game::GuildChatTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketAuctions

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:administrator)
    @moderator = accounts_players(:moderator)
    @outsider = Accounts::Player.create!(steam_id: "76561197961000300", persona_name: "Outsider")
    open_market!
    fund!(@alice, 10_000)
    @guild = Game::FoundGuild.new.call(player: @alice).value!
    Game::JoinGuild.new.call(player: @bob, code: @guild.invite_code).value!
  end

  def post(player, body) = Game::PostGuildMessage.new.call(player:, body:)
  def report(player, message) = Game::ReportGuildMessage.new.call(player:, token: message.token)
  def moderate(player, message, decision) = Game::ModerateGuildMessage.new.call(player:, token: message.token, decision:)

  test "a member writes to their guild, trimmed, and the guild reads it with its author" do
    message = post(@alice, "  Bonjour la filiale  ").value!

    assert_equal "Bonjour la filiale", message.body
    assert_equal [ [ "Bonjour la filiale", @alice ] ], Game::GuildMessagesOf.call(@guild.id).map { [ it.message.body, it.author ] }
  end

  test "an empty message, a message over 500 characters or a player outside a guild is refused" do
    assert_equal :message_empty, post(@alice, "   ").failure
    assert_equal :message_too_long, post(@alice, "a" * 501).failure
    assert post(@alice, "a" * 500).success?
    assert_equal :not_in_guild, post(@outsider, "hello").failure
  end

  test "a member reports another member's message once, never their own nor another guild's" do
    message = post(@alice, "rude").value!

    assert_equal :own_message, report(@alice, message).failure
    assert_equal :message_not_found, report(@outsider, message).failure
    assert report(@bob, message).success?
    assert_equal :already_reported, report(@bob, message).failure
    assert_equal [ message ], Game::GuildMessageQueue.call.map(&:message)
  end

  test "a moderator hides a reported message, or dismisses the report; a player cannot" do
    hidden = post(@alice, "rude").value!
    kept = post(@alice, "fine").value!
    report(@bob, hidden).value!
    report(@bob, kept).value!

    assert_equal :moderator_required, moderate(@alice, hidden, :hide).failure
    assert moderate(@moderator, hidden, :hide).success?
    assert moderate(@moderator, kept, :dismiss).success?

    assert_predicate hidden.reload, :hidden?
    assert_nil kept.reload.reported_at
    assert_empty Game::GuildMessageQueue.call
  end

  test "an erased account takes its guild messages with it and leaves the reports it filed unsigned" do
    own = post(@alice, "mine").value!
    theirs = post(@bob, "theirs").value!
    report(@alice, theirs).value!

    Game::ReleasePlayer.new.call(player: @alice).value!

    assert_not Game::GuildMessage.exists?(own.id)
    assert_nil theirs.reload.reporter_id
    assert theirs.reported_at
  end

  test "the export lists the player's guild seat and messages" do
    post(@alice, "for the record").value!

    export = Game::GuildExportOf.call(@alice)

    assert export.seat.leader
    assert_equal @guild, export.seat.guild
    assert_equal [ "for the record" ], export.messages.map(&:body)
  end
end
