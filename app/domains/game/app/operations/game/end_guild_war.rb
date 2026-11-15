module Game
  class EndGuildWar < ApplicationOperation
    def call(war_id:, now: Time.current)
      transaction do
        war = GuildWar.lock.find(war_id)
        step endable(war)
        winner_id = winner_of(war)
        reward(war, winner_id)
        war.update!(winner_id:, ended_at: now)
        step publish(GuildWarEnded.new(data: { war_id:, winner_id:, points: war.points, opponent_points: war.opponent_points }),
          stream_name: "Game::GuildWar$#{war_id}")
        war
      end
    end

    private

    def endable(war)
      return Failure(:already_ended) if war.ended_at

      war.fully_settled? ? Success() : Failure(:war_under_way)
    end

    def winner_of(war)
      return unless war.opposed?

      by_points = war.points <=> war.opponent_points
      decided = by_points.zero? ? weekly_average_comparison(war) : by_points
      { 1 => war.guild_id, -1 => war.opponent_id }[decided]
    end

    def weekly_average_comparison(war)
      openings = GuildWarDay.where(war_id: war.id).group(:guild_id).sum(:openings)
      rosters = GuildWarMember.where(war_id: war.id).group(:guild_id).count
      (openings.fetch(war.guild_id, 0) * rosters.fetch(war.opponent_id, 0)) <=> (openings.fetch(war.opponent_id, 0) * rosters.fetch(war.guild_id, 0))
    end

    def reward(war, winner_id)
      if !war.opposed?
        GuildTreasury.credit(guild_id: war.guild_id, kind: :war_unopposed, amount: GuildWar::MONEY[:unopposed], war_id: war.id)
      elsif winner_id
        GuildTreasury.credit(guild_id: winner_id, kind: :war_won, amount: GuildWar::MONEY[:won], war_id: war.id)
      else
        war.guild_ids.each { |guild_id| GuildTreasury.credit(guild_id:, kind: :war_drawn, amount: GuildWar::MONEY[:drawn], war_id: war.id) }
      end
    end
  end
end
