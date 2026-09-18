require "test_helper"

# What an intent's lists come back in. Every one of these reads an association,
# and an association with no order is answered in whatever order the query plan
# produces: today SQLite walks an index and hands back something that is neither
# insertion order nor id order. These tests are the standing statement that the
# order a caller sees is the order they gave, and the chaos lane
# (`rake test:chaos`) is what gives them teeth: it reverses every unordered
# result, so an assertion that only agrees with today's plan fails there.
class OutputOrderTest < Minitest::Test
  include IntentRecordDsl

  A = "aaaa111111111111111111111111111111111111".freeze
  B = "bbbb222222222222222222222222222222222222".freeze
  C = "cccc333333333333333333333333333333333333".freeze

  def test_commits_come_back_in_the_order_they_were_attached
    intent = record_intent!(commits: [C, A, B])

    versions = run_cli_ok!("show", intent["intent_id"])["asset_versions"]

    assert_equal([C, A, B], versions.map { |v| v["external_id"] })
  end

  def test_stakeholder_references_come_back_in_the_order_they_were_attached
    refs = [{ "system" => "jira", "uri" => "https://j/3" },
            { "system" => "jira", "uri" => "https://j/1" },
            { "system" => "confluence", "uri" => "https://c/2" }]
    intent = record_intent!(stakeholder_references: refs)

    seen = run_cli_ok!("show", intent["intent_id"])["stakeholder_references"]

    assert_equal(["https://j/3", "https://j/1", "https://c/2"], seen.map { |s| s["uri"] })
  end

  def test_related_intents_come_back_in_the_order_they_were_related
    third = record_intent!(summary: "third")
    first = record_intent!(summary: "first")
    second = record_intent!(summary: "second")
    source = record_intent!(related_intent_ids: [third["intent_id"], first["intent_id"], second["intent_id"]])

    seen = run_cli_ok!("show", source["intent_id"])["related_intents"]

    assert_equal(%w[third first second], seen.map { |i| i["summary"] })
  end

  def test_intents_relating_to_this_one_come_back_in_the_order_they_related_to_it
    target = record_intent!(summary: "target")
    %w[third first second].each do |summary|
      record_intent!(summary: summary, related_intent_ids: [target["intent_id"]])
    end

    seen = run_cli_ok!("show", target["intent_id"])["related_by_intents"]

    assert_equal(%w[third first second], seen.map { |i| i["summary"] })
  end
end

class SourceListOrderTest < Minitest::Test
  include IntentRecordDsl

  def test_matching_sources_come_back_in_the_order_they_were_first_recorded
    record_intent!(stakeholder_references: [{ "system" => "jira", "uri" => "https://j/ACME-42-b" }])
    record_intent!(stakeholder_references: [{ "system" => "jira", "uri" => "https://j/ACME-42-a" }])

    json = run_cli_ok!("by-source", "ACME-42", "--contains")

    assert_equal(["https://j/ACME-42-b", "https://j/ACME-42-a"], json["sources"].map { |s| s["uri"] })
  end
end
