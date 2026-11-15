class GuildLeaderboardsController < ApplicationController
  def show
    authorize :guild, :leaderboard?
    @rows = Game::GuildLeaderboard.call
    @own_guild_id = Game::GuildMembership.where(player_id: current_player.id).pick(:guild_id)
  end
end
