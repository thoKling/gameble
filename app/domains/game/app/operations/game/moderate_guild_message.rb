module Game
  # A moderator settles a reported guild message: hidden for every member, or the report dismissed.
  class ModerateGuildMessage < Operation
    DECISIONS = %i[hide dismiss].freeze

    def call(player:, token:, decision:)
      player = step require_player(player)
      step staff(player)
      step known(decision)

      transaction do
        message = step awaiting(token)
        decision == :hide ? message.update!(hidden_at: Time.current, hidden_by_id: player.id) : message.update!(reported_at: nil, reporter_id: nil)
        step publish(event_for(decision, message, player), stream_name: stream_name(player.id))
        message
      end
    end

    private

    def staff(player) = player.staff? ? Success() : Failure(:moderator_required)

    def known(decision) = DECISIONS.include?(decision) ? Success() : Failure(:unknown_decision)

    def awaiting(token)
      message = token.is_a?(String) ? GuildMessage.awaiting_moderation.lock.find_by(token:) : nil
      message ? Success(message) : Failure(:message_not_found)
    end

    def event_for(decision, message, player)
      data = { message_id: message.id, moderator_id: player.id }
      decision == :hide ? GuildMessageHidden.new(data:) : GuildMessageReportDismissed.new(data:)
    end
  end
end
