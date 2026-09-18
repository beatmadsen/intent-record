require "test_helper"
require "intent_record/web/query_router"

class QueryRouterTest < Minitest::Test
  def route(query)
    IntentRecord::Web::QueryRouter.path_for(query)
  end

  def test_blank_goes_home
    assert_equal "/", route("   ")
  end

  def test_hex_of_four_or_more_chars_goes_to_commit
    assert_equal "/commits/8F3a1c", route(" 8F3a1c ")
  end

  def test_short_hex_is_treated_as_search_text
    assert_match %r{\A/search\?q=}, route("abc")
  end

  def test_url_goes_to_sources_encoded
    assert_equal "/sources?uri=https%3A%2F%2Fj%2FACME-1", route("https://j/ACME-1")
  end

  def test_words_go_to_search_encoded
    assert_equal "/search?q=retry+backoff", route("retry backoff")
  end
end
