# A guild is a small team of players with a generated name, a seat limit, one invite code and its own guild money.
# A player belongs to at most one guild. Founding a guild costs PiCoins, recorded as a guild_fee ledger entry.
# Each week every guild fights one other guild: the roster is frozen at pairing, each day's openings are counted
# per guild, and guild money is recorded entry by entry. Members write to their guild's message thread.
class CreateGameGuilds < ActiveRecord::Migration[8.1]
  LEDGER_KINDS = %w[mint stamp hold release purchase sale commission forfeit guild_fee].freeze
  MONEY_KINDS = %w[openings war_won war_drawn war_unopposed].freeze

  def change
    create_table :game_guilds do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :name_region, null: false
      t.string :name_division, null: false
      t.string :invite_code, null: false, index: { unique: true }
      t.references :leader, null: false, foreign_key: { to_table: :accounts_players }
      t.integer :seats, null: false
      t.bigint :money, null: false, default: 0
      t.datetime :dissolved_at
      t.timestamps

      t.index %i[name_region name_division], unique: true, where: "dissolved_at IS NULL", name: "index_game_guilds_one_active_name"
      t.check_constraint "seats > 0", name: "game_guilds_seats_check"
      t.check_constraint "money >= 0", name: "game_guilds_money_check"
      t.check_constraint "invite_code ~ '^[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}$'", name: "game_guilds_invite_code_check"
    end

    create_table :game_guild_memberships do |t|
      t.references :guild, null: false, foreign_key: { to_table: :game_guilds }
      t.references :player, null: false, index: { unique: true }, foreign_key: { to_table: :accounts_players }
      t.timestamps
    end

    create_table :game_guild_wars do |t|
      t.date :week_start, null: false
      t.references :guild, null: false, index: false, foreign_key: { to_table: :game_guilds }
      t.references :opponent, index: false, foreign_key: { to_table: :game_guilds }
      t.integer :points, null: false, default: 0
      t.integer :opponent_points, null: false, default: 0
      t.date :settled_through
      t.references :winner, foreign_key: { to_table: :game_guilds }
      t.datetime :ended_at
      t.timestamps

      t.index %i[week_start guild_id], unique: true
      t.index %i[week_start opponent_id], unique: true, where: "opponent_id IS NOT NULL"
      t.index :guild_id
      t.index :opponent_id
      t.check_constraint "opponent_id IS NULL OR opponent_id <> guild_id", name: "game_guild_wars_opponent_check"
    end

    create_table :game_guild_war_members do |t|
      t.references :war, null: false, foreign_key: { to_table: :game_guild_wars }
      t.references :guild, null: false, foreign_key: { to_table: :game_guilds }
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.date :week_start, null: false
      t.datetime :created_at, null: false

      t.index %i[player_id week_start], unique: true
    end

    create_table :game_guild_war_days do |t|
      t.references :war, null: false, index: false, foreign_key: { to_table: :game_guild_wars }
      t.references :guild, null: false, foreign_key: { to_table: :game_guilds }
      t.date :day, null: false
      t.integer :openings, null: false, default: 0
      t.timestamps

      t.index %i[war_id guild_id day], unique: true
    end

    create_table :game_guild_money_entries do |t|
      t.references :guild, null: false, foreign_key: { to_table: :game_guilds }
      t.string :kind, null: false
      t.bigint :amount, null: false
      t.references :war, foreign_key: { to_table: :game_guild_wars }
      t.date :day
      t.datetime :created_at, null: false

      t.check_constraint "kind ~ '^(#{MONEY_KINDS.join("|")})$'", name: "game_guild_money_entries_kind_check"
    end

    create_table :game_guild_messages do |t|
      t.string :token, null: false, index: { unique: true }
      t.references :guild, null: false, index: false, foreign_key: { to_table: :game_guilds }
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }
      t.text :body, null: false
      t.datetime :reported_at
      t.references :reporter, foreign_key: { to_table: :accounts_players }
      t.datetime :hidden_at
      t.references :hidden_by, foreign_key: { to_table: :accounts_players }
      t.timestamps

      t.index %i[guild_id created_at]
      t.index :reported_at, where: "reported_at IS NOT NULL AND hidden_at IS NULL", name: "index_game_guild_messages_awaiting_moderation"
      t.check_constraint "char_length(body) BETWEEN 1 AND 500", name: "game_guild_messages_body_check"
    end

    add_check_constraint :game_market_ledger_entries, "kind ~ '^(#{LEDGER_KINDS.join("|")})$'",
      name: "game_market_ledger_entries_kind_with_guild_fee_check", validate: false
  end
end
