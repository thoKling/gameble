class ValidateGameMarketLedgerEntriesGuildFeeKind < ActiveRecord::Migration[8.1]
  OLD_KINDS = %w[mint stamp hold release purchase sale commission forfeit].freeze

  def up
    validate_check_constraint :game_market_ledger_entries, name: "game_market_ledger_entries_kind_with_guild_fee_check"
    remove_check_constraint :game_market_ledger_entries, name: "game_market_ledger_entries_kind_check"
  end

  def down
    add_check_constraint :game_market_ledger_entries, "kind ~ '^(#{OLD_KINDS.join("|")})$'", name: "game_market_ledger_entries_kind_check"
  end
end
