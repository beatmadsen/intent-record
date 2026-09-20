require "test_helper"

# The relevance index is a second copy of text the records already hold, so the
# question it has to answer is not "does it rank" but "is it still true". A copy
# that silently stops being updated ranks yesterday's store forever, and every
# ranking test above it stays green while it does.
class SearchIndexTest < Minitest::Test
  include DbTestSetup

  def indexed(intent_id)
    record = IntentRecord::Models::IntentRecord.find_by!(global_id: intent_id)
    sql = "SELECT summary, body FROM intent_search WHERE rowid = #{record.id}"
    IntentRecord::Models::IntentRecord.connection.select_rows(sql)
  end

  def create!(summary: "Retry fetch", body: "Because flaky.")
    IntentRecord::Commands::Record.new.call("summary" => summary, "body" => body)
  end

  def test_a_recorded_intent_is_indexed_with_its_text
    intent = create!(summary: "Retry fetch", body: "Because flaky.")

    assert_equal [["Retry fetch", "Because flaky."]], indexed(intent["intent_id"])
  end

  def test_editing_a_record_updates_what_the_index_holds
    intent = create!(summary: "Retry fetch")
    record = IntentRecord::Models::IntentRecord.find_by!(global_id: intent["intent_id"])

    record.update!(summary: "Rename the loader")

    assert_equal [["Rename the loader", "Because flaky."]], indexed(intent["intent_id"])
  end

  def test_deleting_a_record_removes_it_from_the_index
    intent = create!
    IntentRecord::Models::IntentRecord.find_by!(global_id: intent["intent_id"]).destroy!

    assert_empty IntentRecord::Models::IntentRecord.connection.select_rows("SELECT rowid FROM intent_search")
  end
end

# The upgrade path. A store written before the index existed holds records the
# index has never seen, and ranking them from the first run afterwards is the
# difference between a feature that works on adoption and one that works on
# whatever gets recorded next. Migrating up from the schema before the index is
# the only way to exercise it; a store built by the current migrations has
# always had it.
class SearchIndexUpgradeTest < Minitest::Test
  include DbTestSetup

  SCHEMA_BEFORE_THE_INDEX = 20_260_918_000_001

  def migration_context
    ActiveRecord::MigrationContext.new(IntentRecord::Database::MIGRATIONS_PATH)
  end

  def connection
    IntentRecord::Models::IntentRecord.connection
  end

  def roll_back_to_the_schema_before_the_index
    ActiveRecord::Migration.verbose = false
    migration_context.down(SCHEMA_BEFORE_THE_INDEX)
  end

  def insert_a_record_the_index_has_never_seen
    connection.execute(<<~SQL)
      INSERT INTO intent_records (global_id, summary, body, created_at)
      VALUES ('Legacy1', 'Retry flaky fetches', 'Older than the index.', '2020-01-01 00:00:00')
    SQL
  end

  def summaries_matching(expression)
    sql = "SELECT summary FROM intent_search WHERE intent_search MATCH #{connection.quote(expression)}"
    connection.select_values(sql)
  end

  def test_records_written_before_the_index_existed_are_indexed_by_the_migration
    roll_back_to_the_schema_before_the_index
    insert_a_record_the_index_has_never_seen

    migration_context.migrate

    assert_equal ["Retry flaky fetches"], summaries_matching('"retry"')
  end
end
