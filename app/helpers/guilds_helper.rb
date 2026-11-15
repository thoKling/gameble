module GuildsHelper
  def guild_name(guild)
    t("guilds.name", region: t("guilds.regions.#{guild.name_region}"), division: t("guilds.divisions.#{guild.name_division}"))
  end

  def guild_war_average(side)
    return number_with_precision(0, precision: 1) if side.roster.zero?

    number_with_precision(side.today.to_f / side.roster, precision: 1)
  end

  def guild_war_outcome(outcome)
    case outcome.result
    when :unopposed then t("guilds.war.last.unopposed")
    else t("guilds.war.last.#{outcome.result}", rival: guild_name(outcome.rival), points: outcome.points, rival_points: outcome.rival_points)
    end
  end
end
