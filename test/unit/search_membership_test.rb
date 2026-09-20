require "test_helper"

# Which records a search answers with. Two ways of matching sit behind one
# condition, and they are not interchangeable: substring matching reads the term
# as the literal it is, and the index reads it as a word and so also finds the
# other forms of that word. A term gets the index arm only when it is safe to,
# which MatchExpressionWordTermsTest settles separately.
class SearchMembershipTest < Minitest::Test
  Subject = IntentRecord::SearchMembership

  def condition(terms, match: "any")
    Subject.new(terms: terms.map { |t| IntentRecord::SearchTerm.parse(t) }, match: match).condition
  end

  def sql(terms, match: "any")
    condition(terms, match: match).first
  end

  def binds(terms, match: "any")
    condition(terms, match: match).drop(1)
  end

  def test_a_word_term_is_matched_as_a_substring_and_as_a_word
    assert_match(/LIKE.*OR EXISTS/m, sql(["retry"]))
  end

  def test_a_term_carrying_punctuation_is_matched_only_as_a_substring
    refute_includes sql(["100%"]), "EXISTS"
  end

  def test_every_term_must_match_under_match_all
    assert_includes sql(%w[retry backoff], match: "all"), ") AND ("
  end

  def test_any_term_may_match_by_default
    assert_includes sql(%w[retry backoff]), ") OR ("
  end

  # The classic way this breaks. A bind that does not line up with its
  # placeholder searches for the wrong text and still returns rows, so the
  # count is worth pinning on its own.
  def test_each_placeholder_is_given_exactly_one_bind
    %w[retry 100% ünïcödé].permutation(2) do |terms|
      assert_equal sql(terms).count("?"), binds(terms).size, "binds do not line up for #{terms.inspect}"
    end
  end

  def test_a_word_term_binds_its_substring_pattern_and_its_index_phrase
    assert_includes binds(["retry"]), "%retry%"
    assert_includes binds(["retry"]), '"retry"'
  end

  # A term naming a field looks in that field only, so it binds one pattern
  # rather than one per field.
  def test_a_term_naming_a_field_binds_one_substring_pattern
    assert_equal 1, binds(["summary:retry"]).count("%retry%")
  end

  # Only summary and body are in the index, so naming a stakeholder field leaves
  # the substring arm alone to answer the term.
  def test_a_term_naming_a_stakeholder_field_is_matched_only_as_a_substring
    refute_includes sql(["uri:acme"]), "EXISTS"
  end
end
