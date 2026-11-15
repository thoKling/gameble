# A guild is a small team of players with a generated name, a seat limit and one invite code.
# A player belongs to at most one guild. Founding a guild costs PiCoins, recorded as a guild_fee ledger entry.
class CreateGameGuilds < ActiveRecord::Migration[8.1]
  LEDGER_KINDS = %w[mint stamp hold release purchase sale commission forfeit guild_fee].freeze

  def change
    create_table :game_guilds do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :name_region, null: false
      t.string :name_division, null: false
      t.string :invite_code, null: false, index: { unique: true }
      t.references :leader, null: false, foreign_key: { to_table: :accounts_players }
      t.integer :seats, null: false
      t.timestamps

      t.index %i[name_region name_division], unique: true
      t.check_constraint "seats > 0", name: "game_guilds_seats_check"
      t.check_constraint "invite_code ~ '^[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}$'", name: "game_guilds_invite_code_check"
    end

    create_table :game_guild_memberships do |t|
      t.references :guild, null: false, foreign_key: { to_table: :game_guilds, on_delete: :cascade }
      t.references :player, null: false, index: { unique: true }, foreign_key: { to_table: :accounts_players }
      t.timestamps
    end

    add_check_constraint :game_market_ledger_entries, "kind ~ '^(#{LEDGER_KINDS.join("|")})$'",
      name: "game_market_ledger_entries_kind_with_guild_fee_check", validate: false
  end
end
