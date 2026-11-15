module GuildsHelper
  def guild_name(guild)
    t("guilds.name", region: t("guilds.regions.#{guild.name_region}"), division: t("guilds.divisions.#{guild.name_division}"))
  end
end
