require "test_helper"

# One term a person typed, read into the field it names and the text to look for.
#
# The hazard is that a ticket URL has a colon in it too, so only the known field
# names count as a name. Anything else before a colon is part of the term.
class SearchTermTest < Minitest::Test
  Subject = IntentRecord::SearchTerm

  def parse(raw)
    Subject.parse(raw)
  end

  def test_a_plain_term_looks_in_every_field
    term = parse("retry")

    assert_equal "retry", term.text
    assert_equal Subject::ALL_FIELDS, term.fields
  end

  def test_naming_the_summary_narrows_the_fields_to_it
    assert_equal ["intent_records.summary"], parse("summary:retry").fields
  end

  def test_the_name_is_not_part_of_the_text_to_look_for
    assert_equal "retry", parse("summary:retry").text
  end

  # Every other name the tool takes is lowercased on input, and a field name
  # that is not would send `Summary:retry` off to be matched as that literal.
  def test_a_field_name_is_read_whatever_its_case
    assert_equal ["intent_records.summary"], parse("SUMMARY:retry").fields
    assert_equal "retry", parse("Summary:retry").text
  end

  # The shell hands `uri: acme-42` over as one word with the space inside it.
  # The space is not part of what the person is looking for, and left in it
  # binds a substring pattern that begins with a space and matches nothing.
  def test_space_after_the_name_is_not_part_of_the_text
    assert_equal "acme-42", parse("uri: acme-42").text
  end

  def test_naming_the_body_narrows_the_fields_to_it
    assert_equal ["intent_records.body"], parse("body:retry").fields
  end

  def test_a_stakeholder_field_can_be_named
    assert_equal ["stakeholder_sources.uri"], parse("uri:acme-42").fields
  end

  # A ticket url carries a colon and would be read as a field named `https`.
  def test_an_unknown_name_before_a_colon_is_left_in_the_text
    term = parse("https://j/ACME-42")

    assert_equal "https://j/ACME-42", term.text
    assert_equal Subject::ALL_FIELDS, term.fields
  end

  def test_a_name_with_nothing_after_it_is_refused
    error = assert_raises(IntentRecord::ValidationError) { parse("summary:") }
    assert_match(/summary/, error.message)
  end

  # Only summary and body are in the relevance index. Naming a stakeholder field
  # therefore leaves nothing for the index to answer, which is a different thing
  # from a plain term, where the index answers over both of its columns.
  def test_a_named_record_field_is_answered_by_that_column_of_the_index
    assert_equal "summary", parse("summary:retry").index_column
  end

  def test_a_plain_term_is_answered_by_the_index_over_all_its_columns
    term = parse("retry")

    assert term.indexable?
    assert_nil term.index_column
  end

  def test_a_named_stakeholder_field_is_not_answered_by_the_index_at_all
    refute parse("uri:acme-42").indexable?
  end

  # A term carrying punctuation is one the index cannot be trusted with, whether
  # or not it names a field.
  def test_a_named_field_holding_a_literal_is_not_answered_by_the_index
    refute parse("summary:100%").indexable?
  end
end
