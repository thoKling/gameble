require "test_helper"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/steam_sign_in"

class GuildsControllerTest < ActionDispatch::IntegrationTest
  include MarketSettings
  include MarketAuctions
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    open_market!
  end

  test "a visitor is sent to sign in" do
    get guild_path(locale: :en)

    assert_response :redirect
  end

  test "a player outside a guild sees the fee, their balance and the code form" do
    fund!(@player, 12_000)
    sign_in(@player)

    get guild_path(locale: :fr)

    assert_response :success
    assert_select "main h1", "Guilde"
    assert_select ".guild__found .guild__fee", /10\D000/
    assert_select ".guild__found form[action=?] button", guild_path(locale: :fr), "Fonder une guilde"
    assert_select ".guild__join form[action=?]", join_guild_path(locale: :fr)
  end

  test "a player short of the fee sees the founding button disabled" do
    sign_in(@player)

    get guild_path(locale: :en)

    assert_select ".guild__found button[disabled]", "Found a guild"
  end

  test "founding, then a friend joining with the code, shows both members to the leader" do
    fund!(@player, 12_000)
    sign_in(@player)
    post guild_path(locale: :en)
    assert_redirected_to guild_path(locale: :en)
    guild = Game::Guild.sole

    sign_in(@other)
    post join_guild_path(locale: :en), params: { code: guild.invite_code }
    assert_redirected_to guild_path(locale: :en)

    sign_in(@player)
    get guild_path(locale: :en)
    assert_select ".guild__code", guild.invite_code
    assert_select ".guild__seats", "2 of 3 seats taken"
    assert_select ".guild__member", 2
    assert_select ".guild__member form[action=?]", remove_guild_member_path(locale: :en, token: @other.token)
    assert_no_match(/>#{guild.id}</, response.body)
  end

  test "a failure comes back as an alert on the guild page" do
    sign_in(@player)

    post join_guild_path(locale: :en), params: { code: "AAAA-BBBB" }
    follow_redirect!

    assert_match "No guild has this code.", response.body
  end

  test "a member leaves and a leader removes by token" do
    fund!(@player, 12_000)
    guild = Game::FoundGuild.new.call(player: @player).value!
    Game::JoinGuild.new.call(player: @other, code: guild.invite_code).value!
    sign_in(@player)

    post remove_guild_member_path(locale: :en, token: @other.token)
    assert_equal [ @player.id ], Game::GuildMembership.pluck(:player_id)

    post leave_guild_path(locale: :en)
    assert_predicate guild.reload, :dissolved_at
  end

  test "a member reads the war, the guild money and the chat, writes a message and reports one" do
    fund!(@player, 12_000)
    guild = Game::FoundGuild.new.call(player: @player).value!
    Game::JoinGuild.new.call(player: @other, code: guild.invite_code).value!
    message = Game::PostGuildMessage.new.call(player: @other, body: "Bienvenue <b>à tous</b>").value!
    sign_in(@player)

    get guild_path(locale: :fr)

    assert_select ".guild__money", "Argent de guilde\u202F: 0"
    assert_select ".guild-war", /Votre guilde entre en guerre lundi prochain/
    assert_select ".guild-chat__body", "Bienvenue <b>à tous</b>"
    assert_select ".guild-chat__line form[action=?]", report_guild_message_path(locale: :fr, token: message.token)

    post guild_messages_path(locale: :fr), params: { body: "Merci" }
    assert_redirected_to guild_path(locale: :fr, anchor: "guild-chat")
    assert_equal [ "Bienvenue <b>à tous</b>", "Merci" ], Game::GuildMessage.order(:id).pluck(:body)

    post report_guild_message_path(locale: :fr, token: message.token)
    assert message.reload.reported_at
  end

  test "a moderator reads the reported guild messages and hides one" do
    fund!(@player, 12_000)
    guild = Game::FoundGuild.new.call(player: @player).value!
    Game::JoinGuild.new.call(player: @other, code: guild.invite_code).value!
    message = Game::PostGuildMessage.new.call(player: @player, body: "rude").value!
    Game::ReportGuildMessage.new.call(player: @other, token: message.token).value!
    sign_in(@other)

    get back_office_guild_messages_path(locale: :en)
    assert_select "tr[data-guild-message=?] .guild-message-body", message.token, "rude"

    post back_office_hide_guild_message_path(locale: :en, token: message.token)
    assert_redirected_to back_office_guild_messages_path(locale: :en)
    assert_predicate message.reload, :hidden?
  end

  test "a player who is not staff cannot reach the guild messages queue" do
    sign_in(@player)

    get back_office_guild_messages_path(locale: :en)

    assert_response :not_found
  end
end
