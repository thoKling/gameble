module Game
  # One day of a war between two guilds: the guild ahead on capsules opened, and the guild ahead on capsules opened per rostered member.
  GuildWarDayScore = Data.define(:openings, :opponent_openings, :roster, :opponent_roster) do
    def points = GuildWar::POINTS_PER_DAY * [ ahead_on_openings == :guild, ahead_on_average == :guild ].count(true)
    def opponent_points = GuildWar::POINTS_PER_DAY * [ ahead_on_openings == :opponent, ahead_on_average == :opponent ].count(true)

    def ahead_on_openings = ahead(openings <=> opponent_openings)

    # Compared as cross products so a fraction never rounds a tie away.
    def ahead_on_average = ahead((openings * opponent_roster) <=> (opponent_openings * roster))

    private

    def ahead(comparison) = { 1 => :guild, -1 => :opponent }[comparison]
  end
end
