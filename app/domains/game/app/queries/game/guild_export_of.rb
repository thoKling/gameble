module Game
  # A player's guild seat and the guild messages they wrote, for their data export.
  module GuildExportOf
    Seat = Data.define(:guild, :leader, :joined_at)
    Message = Data.define(:body, :sent_at, :hidden_at)
    Result = Data.define(:seat, :messages)

    def self.call(player)
      membership = GuildMembership.find_by(player_id: player.id)
      seat = membership && Seat.new(guild: membership.guild, leader: membership.guild.leader_id == player.id, joined_at: membership.created_at)
      messages = GuildMessage.where(player_id: player.id).order(:created_at, :id).pluck(:body, :created_at, :hidden_at)
        .map { |body, sent_at, hidden_at| Message.new(body:, sent_at:, hidden_at:) }
      Result.new(seat:, messages:)
    end
  end
end
