module BackOffice
  class GuildMessagesController < BaseController
    rate_limit to: 30, within: 1.minute, only: %i[hide dismiss]

    def index
      authorize [ :back_office, :guild_messages ], :index?
      @rows = Game::GuildMessageQueue.call
    end

    def hide
      authorize [ :back_office, :guild_messages ], :hide?
      moderate(:hide, t(".hidden"))
    end

    def dismiss
      authorize [ :back_office, :guild_messages ], :dismiss?
      moderate(:dismiss, t(".dismissed"))
    end

    private
      def moderate(decision, notice)
        result = Game::ModerateGuildMessage.new.call(player: current_player, token: params[:token], decision:)
        if result.success?
          redirect_to back_office_guild_messages_path, notice:, status: :see_other
        else
          redirect_refused Game::ModerateGuildMessage, result, back_office_guild_messages_path
        end
      end
  end
end
