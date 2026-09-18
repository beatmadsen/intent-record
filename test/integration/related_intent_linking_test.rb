require "test_helper"

# IntentLinker's own rules. The ids it is given are looked up verbatim, so
# anything the input keeps has to be gone before it gets here.
class RelatedIntentLinkingTest < Minitest::Test
  include DbTestSetup

  def test_a_related_id_links_the_two_records
    earlier = record
    later = record("related_intent_ids" => [earlier["intent_id"]])

    assert_equal [earlier["intent_id"]], ids(later["related_intents"])
  end

  # Every other string field is trimmed on the way in, and an id that names an
  # existing record must not stop naming it because of the spaces around it.
  def test_a_padded_related_id_names_the_same_record
    earlier = record
    later = record("related_intent_ids" => ["  #{earlier["intent_id"]}  "])

    assert_equal [earlier["intent_id"]], ids(later["related_intents"])
  end

  def test_the_relation_is_visible_from_the_other_side
    earlier = record
    later = record("related_intent_ids" => [earlier["intent_id"]])

    assert_equal [later["intent_id"]], ids(shown(earlier)["related_by_intents"])
  end

  def test_an_unknown_related_id_is_not_found
    error = assert_raises(IntentRecord::NotFoundError) { record("related_intent_ids" => %w[zzzzzzz]) }

    assert_match(/Related intent record not found: zzzzzzz/, error.message)
  end

  def test_naming_the_same_relation_twice_stores_one_link
    earlier = record
    later = record("related_intent_ids" => [earlier["intent_id"]])
    attach(later, earlier["intent_id"])

    assert_equal 1, IntentRecord::Models::IntentRecordLink.count
  end

  # Nothing forbids two records relating to each other, only a record relating
  # to itself, so a pair pointing both ways is two links rather than an error.
  def test_two_records_may_relate_to_each_other
    earlier = record
    later = record("related_intent_ids" => [earlier["intent_id"]])
    attach(earlier, later["intent_id"])

    assert_equal 2, IntentRecord::Models::IntentRecordLink.count
  end

  # A padded id names the same record, so it is also the same record for the
  # purpose of refusing a self link.
  def test_a_padded_self_link_is_still_refused
    only = record

    error = assert_raises(IntentRecord::ValidationError) do
      attach(only, "  #{only["intent_id"]}  ")
    end

    assert_match(/cannot link to itself/, error.message)
  end

  private

  def ids(entries)
    entries.map { |entry| entry["intent_id"] }
  end

  def record(input = {})
    IntentRecord::Commands::Record.new.call({ "summary" => "s", "body" => "b" }.merge(input))
  end

  def attach(target, related_id)
    IntentRecord::Commands::Attach.new(intent_id: target["intent_id"]).call("related_intent_ids" => [related_id])
  end

  def shown(record)
    IntentRecord::Commands::Show.new(intent_id: record["intent_id"]).call
  end
end
