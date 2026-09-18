require "test_helper"

# Formatter reads four associations per record. Asking each record for them in
# turn costs a query apiece, which is invisible on one record and is most of the
# work on two hundred. What is asserted is the shape rather than a count: adding
# records must not add queries.
class FormattingAListDoesNotQueryPerRecordTest < Minitest::Test
  include DbTestSetup

  SHARED_COMMIT = ("7" * 40).freeze
  SHARED_URI = "https://j/shared".freeze

  def test_recent_costs_the_same_number_of_queries_for_five_records_as_for_one
    assert_equal queries_for_recent(1), queries_for_recent(5)
  end

  def test_search_costs_the_same_number_of_queries_for_five_records_as_for_one
    assert_equal queries_for_search(1), queries_for_search(5)
  end

  def test_by_source_costs_the_same_number_of_queries_for_five_records_as_for_one
    assert_equal queries_for_by_source(1), queries_for_by_source(5)
  end

  def test_lookup_costs_the_same_number_of_queries_for_five_records_as_for_one
    assert_equal queries_for_lookup(1), queries_for_lookup(5)
  end

  # The four above would pass just as well if nothing were formatted, or if the
  # counter saw nothing, so both are checked.
  def test_every_seeded_record_is_formatted
    seed(3)

    assert_equal 3, IntentRecord::Commands::Recent.new(limit: 100).call["intents"].size
  end

  def test_the_counter_sees_queries_at_all
    seed(1)

    refute_empty(queries_while { IntentRecord::Commands::Recent.new(limit: 100).call })
  end

  private

  def queries_for_recent(count)
    reset(count)
    queries_while { IntentRecord::Commands::Recent.new(limit: 100).call }.size
  end

  def queries_for_search(count)
    reset(count)
    queries_while { IntentRecord::Commands::Search.new(terms: %w[intent], match: "any").call }.size
  end

  # Every record here shares one stakeholder source, so the number of sources is
  # fixed and what varies is how many intents hang off it.
  def queries_for_by_source(count)
    reset(count, uri: SHARED_URI)
    queries_while { IntentRecord::Commands::BySource.new(uri: SHARED_URI).call }.size
  end

  # Likewise one commit shared by every record.
  def queries_for_lookup(count)
    reset(count, commit: SHARED_COMMIT)
    queries_while { IntentRecord::Commands::Lookup.new(external_id: SHARED_COMMIT).call }.size
  end

  def reset(count, **shared)
    IntentRecord::Models::IntentRecord.destroy_all
    seed(count, **shared)
  end

  def seed(count, commit: nil, uri: nil)
    (1..count).each do |n|
      IntentRecord::Commands::Record.new.call(
        "summary" => "intent #{n}", "body" => "b", "commits" => [commit || format("%040d", n)],
        "stakeholder_references" => [{ "system" => "jira", "uri" => uri || "https://j/#{n}", "title" => "T#{n}" }]
      )
    end
  end
end
