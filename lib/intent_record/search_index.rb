module IntentRecord
  # The FTS5 table over intent records, created by the migration of the same
  # name. Named here once, for the two modules that read it.
  module SearchIndex
    TABLE = "intent_search".freeze
  end
end
