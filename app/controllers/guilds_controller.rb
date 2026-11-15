class GuildsController < ApplicationController
  throttle_player to: 20, only: %i[create join leave remove], path: -> { guild_path }, alert: "guilds.throttled"

  def show
    authorize :guild, :show?
    @guild = Game::GuildOf.call(current_player)
    @balance = Game::Market::Balance.call(current_player).available unless @guild
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

  private
    def report(result, operation)
      if result.success?
        flash[:notice] = yield
      else
        flash[:alert] = operation.failure_message(result.failure)
      end
      redirect_to guild_path, status: :see_other
    end
end
