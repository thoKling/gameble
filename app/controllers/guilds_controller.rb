class GuildsController < ApplicationController
  throttle_player to: 20, only: %i[create join leave remove report_message], path: -> { guild_path }, alert: "guilds.throttled"
  throttle_player to: 10, only: :post_message, path: -> { guild_path(anchor: "guild-chat") }, alert: "guilds.chat_throttled"

  def show
    authorize :guild, :show?
    @guild = Game::GuildOf.call(current_player)
    if @guild
      @war = Game::GuildWarOf.call(@guild.guild)
      @last_war = Game::GuildWarOf.last_outcome(@guild.guild)
      @messages = Game::GuildMessagesOf.call(@guild.guild.id)
    else
      @balance = Game::Market::Balance.call(current_player).available
    end
  end

  def create
    authorize :guild, :create?

    result = Game::FoundGuild.new.call(player: current_player)
    report(result, Game::FoundGuild) { t("guilds.founded", name: helpers.guild_name(result.value!)) }
  end

  def join
    authorize :guild, :join?

    result = Game::JoinGuild.new.call(player: current_player, code: params[:code].to_s)
    report(result, Game::JoinGuild) { t("guilds.joined", name: helpers.guild_name(result.value!)) }
  end

  def leave
    authorize :guild, :leave?

    result = Game::LeaveGuild.new.call(player: current_player)
    report(result, Game::LeaveGuild) { t("guilds.left") }
  end

  def remove
    authorize :guild, :remove?

    result = Game::RemoveGuildMember.new.call(player: current_player, member: Accounts::PlayerByToken.call(params[:token]))
    report(result, Game::RemoveGuildMember) { t("guilds.removed", name: helpers.friend_name(result.value!)) }
  end

  def post_message
    authorize :guild, :post_message?

    result = Game::PostGuildMessage.new.call(player: current_player, body: params[:body].to_s)
    flash[:alert] = Game::PostGuildMessage.failure_message(result.failure) if result.failure?
    redirect_to guild_path(anchor: "guild-chat"), status: :see_other
  end

  def report_message
    authorize :guild, :report?

    result = Game::ReportGuildMessage.new.call(player: current_player, token: params[:token])
    report(result, Game::ReportGuildMessage, anchor: "guild-chat") { t("guilds.message_reported") }
  end

  private
    def report(result, operation, anchor: nil)
      if result.success?
        flash[:notice] = yield
      else
        flash[:alert] = operation.failure_message(result.failure)
      end
      redirect_to guild_path(anchor:), status: :see_other
    end
end
