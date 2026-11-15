module Game
  module Handlers
    module PackOpened
      def self.call(event)
        opened_at = event.metadata[:timestamp] || Time.current
        WeeklyContribution.record_opening(event.data.fetch(:player_id), opened_at)
        GuildWarDay.record_opening(event.data.fetch(:player_id), opened_at)
        Fortune.record_opening(event.data.fetch(:pack_id))
      end
    end
  end
end
