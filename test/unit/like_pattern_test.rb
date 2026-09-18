require "test_helper"

class LikePatternTest < Minitest::Test
  P = IntentRecord::LikePattern

  # The escape character in the ESCAPE clause and the one ActiveRecord inserts
  # have to be the same character, and neither side is ours to choose. Derived
  # from what sanitize_sql_like actually does rather than written out twice, so
  # this fails if ActiveRecord ever escapes with something else.
  def test_the_escape_clause_names_the_character_activerecord_escapes_with
    inserted = ActiveRecord::Base.sanitize_sql_like("%")[0]

    assert_equal "ESCAPE '#{inserted}'", IntentRecord::LikePattern::ESCAPE
  end

  def test_a_substring_fragment_carries_the_escape_clause
    assert P.contains("x").end_with?(P::ESCAPE)
  end

  def test_a_prefix_fragment_carries_the_escape_clause
    assert P.prefix("x").end_with?(P::ESCAPE)
  end

  # ULOWER is the Unicode-aware lowercase registered on each connection; SQLite's
  # own LOWER folds ASCII only, so a substring search must not use it.
  def test_a_substring_match_lowercases_the_column_with_ulower
    assert_includes P.contains("summary"), "ULOWER(summary)"
  end

  # Hash-based ids are stored lowercase already, so a prefix match compares the
  # column as it is rather than paying for a function call on every row.
  def test_a_prefix_match_does_not_lowercase_the_column
    refute_includes P.prefix("external_id"), "ULOWER"
  end

  def test_a_substring_bind_matches_anywhere_in_the_value
    assert_equal "%term%", P.contains_bind("term")
  end

  def test_a_substring_bind_is_lowercased_to_meet_the_lowercased_column
    assert_equal "%abc%", P.contains_bind("ABC")
  end

  def test_a_prefix_bind_matches_only_at_the_start
    assert_equal "term%", P.prefix_bind("term")
  end

  def test_a_prefix_bind_keeps_the_case_it_was_given
    assert_equal "ABC%", P.prefix_bind("ABC")
  end

  def test_a_percent_in_the_term_is_escaped_rather_than_matching_anything
    assert_equal "%100\\%%", P.contains_bind("100%")
  end

  def test_an_underscore_in_the_term_is_escaped_rather_than_matching_one_character
    assert_equal "%a\\_b%", P.contains_bind("a_b")
  end

  # The escape character escaping itself. Missing this is invisible until a term
  # contains a backslash, and then the pattern means something else entirely.
  def test_the_escape_character_in_the_term_is_itself_escaped
    assert_equal "%a\\\\b%", P.contains_bind("a\\b")
  end

  def test_a_prefix_bind_escapes_wildcards_too
    assert_equal "a\\%b\\_c%", P.prefix_bind("a%b_c")
  end
end
