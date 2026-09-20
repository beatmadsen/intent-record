require "test_helper"

# Naming a field on a term, for the case where a person knows what they are
# looking for and a common word appears everywhere. Ranking already puts a
# summary match first; this is for excluding the rest rather than ordering it.
class SearchFieldTest < Minitest::Test
  include IntentRecordDsl

  def found(*argv)
    run_cli_ok!("search", *argv)["intents"].map { |r| r["intent_id"] }
  end

  def test_naming_the_summary_excludes_a_match_found_only_in_a_body
    hit = record_intent!(summary: "Retry the fetch", body: "Nothing telling.")
    record_intent!(summary: "Nothing telling", body: "We retry the fetch.")

    assert_equal([hit["intent_id"]], found("summary:retry"))
  end

  def test_naming_the_body_excludes_a_match_found_only_in_a_summary
    record_intent!(summary: "Retry the fetch", body: "Nothing telling.")
    hit = record_intent!(summary: "Nothing telling", body: "We retry the fetch.")

    assert_equal([hit["intent_id"]], found("body:retry"))
  end

  def test_naming_a_field_still_matches_the_other_forms_of_a_word
    hit = record_intent!(summary: "Retried the fetch", body: "b")

    assert_equal([hit["intent_id"]], found("summary:retry"))
  end

  def test_a_ticket_uri_can_be_named_as_the_field
    refs = [{ "system" => "jira", "uri" => "https://j/browse/ACME-42" }]
    hit = record_intent!(summary: "Nothing telling", body: "b", stakeholder_references: refs)
    record_intent!(summary: "ACME-42 in the summary", body: "b")

    assert_equal([hit["intent_id"]], found("uri:acme-42"))
  end

  # The hazard this feature brings with it. A ticket URL has a colon in it and
  # would be read as a field named `https` unless only the known names count.
  # Each has a decoy that the remainder after the colon would match on its own,
  # so an implementation that dropped an unknown name and searched the rest
  # would answer with two records and fail here.
  def test_a_term_that_merely_contains_a_colon_is_not_read_as_a_field
    refs = [{ "system" => "jira", "uri" => "https://j/browse/ACME-42" }]
    hit = record_intent!(summary: "Nothing telling", body: "b", stakeholder_references: refs)
    record_intent!(summary: "Mentions //j/browse/ACME-42 without the scheme", body: "b")

    assert_equal([hit["intent_id"]], found("https://j/browse/ACME-42"))
  end

  def test_an_unknown_name_before_a_colon_is_part_of_the_term
    hit = record_intent!(summary: "Wrote author:erik in the summary", body: "b")
    record_intent!(summary: "Mentions erik alone", body: "b")

    assert_equal([hit["intent_id"]], found("author:erik"))
  end

  def test_a_space_after_the_field_name_does_not_stop_the_term_matching
    refs = [{ "system" => "jira", "uri" => "https://j/browse/ACME-42" }]
    hit = record_intent!(summary: "Nothing telling", body: "b", stakeholder_references: refs)

    assert_equal([hit["intent_id"]], found("uri: acme-42"))
  end

  def test_naming_a_field_with_nothing_to_look_for_is_refused
    assert_cli_rejected run_cli("search", "summary:"), matching: /summary/
  end
end
