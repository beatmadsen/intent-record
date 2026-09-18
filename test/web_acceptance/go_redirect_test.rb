require "test_helper"
require "intent_record/web/app"

class GoRedirectTest < WebAcceptanceCase
  def test_hex_query_goes_to_commit_page
    get "/go", q: " #{HASH[0, 10]} "

    assert_equal 302, last_response.status
    assert_equal "/commits/#{HASH[0, 10]}", URI(last_response.location).path
  end

  def test_url_query_goes_to_sources_page
    get "/go", q: "https://j/ACME-1"

    assert_equal 302, last_response.status
    assert_match %r{\A/sources\?uri=}, URI(last_response.location).request_uri
  end

  def test_words_go_to_search_page
    get "/go", q: "retry backoff"

    assert_equal 302, last_response.status
    assert_match %r{\A/search\?q=}, URI(last_response.location).request_uri
  end

  def test_blank_query_returns_home
    get "/go", q: "  "

    assert_equal 302, last_response.status
    assert_equal "/", URI(last_response.location).path
  end
end
