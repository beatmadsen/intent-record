require "test_helper"

class QaUnicodeSearchTest < Minitest::Test
  include IntentRecordDsl

  def test_search_is_case_insensitive_for_non_ascii_letters
    hit = record_intent!(summary: "Ünïcödé 日本語", body: "b")

    assert_equal([hit["intent_id"]], run_cli_ok!("search", "ünïcödé")["intents"].map { |r| r["intent_id"] })
    assert_equal([hit["intent_id"]], run_cli_ok!("search", "ÜNÏCÖDÉ")["intents"].map { |r| r["intent_id"] })
  end
end

class QaInputShapeTest < Minitest::Test
  include IntentRecordDsl

  def test_blank_author_is_stored_as_null
    json = record_intent!(author: "  ")

    assert_nil json["author"]
    assert_nil run_cli_ok!("show", json["intent_id"])["author"]
  end

  def test_summary_and_body_are_trimmed_and_summary_is_one_line
    json = record_intent!(summary: "  two\nlines  ", body: "  padded  ")

    assert_equal "two lines", json["summary"]
    assert_equal "padded", json["body"]
  end

  def test_null_link_arrays_are_treated_as_absent
    assert_cli_ok run_cli("record", stdin: { "summary" => "s", "body" => "b", "commits" => nil })
  end

  def test_attach_with_non_array_related_ids_names_the_field
    id = record_intent!["intent_id"]

    assert_cli_rejected run_cli("attach", id, stdin: { "related_intent_ids" => "x" }), matching: /must be an array/
  end

  def test_record_returns_the_full_record
    json = record_intent!(commits: ["a" * 40])

    assert_equal(["a" * 40], json["asset_versions"].map { |v| v["external_id"] })
    assert_equal "Because reasons.", json["body"]
  end
end

class QaStakeholderNormalisationTest < Minitest::Test
  include IntentRecordDsl

  def test_uri_scheme_host_case_and_trailing_slash_are_normalised
    variants = ["https://acme.atlassian.net/browse/ACME-42", "https://acme.atlassian.net/browse/ACME-42/",
                "HTTPS://ACME.ATLASSIAN.NET/browse/ACME-42"]
    variants.each { |uri| record_intent!(stakeholder_references: [{ "system" => "jira", "uri" => uri }]) }

    assert_equal 1, IntentRecord::Models::StakeholderSource.count
    assert_equal 3, run_cli_ok!("by-source", variants.last)["intents"].size
  end

  def test_path_case_is_preserved
    record_intent!(stakeholder_references: [{ "system" => "jira", "uri" => "https://j/browse/ACME-42" }])

    assert_equal "https://j/browse/ACME-42", IntentRecord::Models::StakeholderSource.sole.uri
  end

  def test_later_non_blank_title_replaces_earlier_one
    ref = { "system" => "jira", "uri" => "https://j/1", "title" => "Old" }
    record_intent!(stakeholder_references: [ref])
    json = record_intent!(stakeholder_references: [ref.merge("title" => "Renamed")])

    assert_equal "Renamed", json["stakeholder_references"].sole["title"]
    record_intent!(stakeholder_references: [ref.merge("title" => nil)])
    assert_equal "Renamed", IntentRecord::Models::StakeholderSource.sole.title
  end

  def test_system_names_are_slugged
    record_intent!(stakeholder_references: [{ "system" => "  My Tracker ", "uri" => "https://t/1" }])

    assert_equal "my-tracker", IntentRecord::Models::StakeholderSystem.order(:id).last.name
  end

  def test_by_source_always_returns_sources_array
    assert_equal [], run_cli_ok!("by-source", "https://none")["sources"]
    record_intent!(stakeholder_references: [{ "system" => "jira", "uri" => "https://j/1" }])
    assert_equal 1, run_cli_ok!("by-source", "https://j/1")["sources"].size
  end
end
