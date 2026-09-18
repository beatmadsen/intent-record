require "rack/test"
require_relative "intent_record_dsl"

# Base class for web acceptance tests: a fresh db per test and the Sinatra app under Rack::Test.
class WebAcceptanceCase < Minitest::Test
  include Rack::Test::Methods
  include IntentRecordDsl

  HASH = "8f3a1c2d9e4b5f60718293a4b5c6d7e8f9a0b1c2".freeze

  def app
    IntentRecord::Web::App
  end

  def assert_body_includes(text)
    assert_includes last_response.body, text, "response body lacks #{text.inspect}"
  end

  def refute_body_includes(text)
    refute_includes last_response.body, text, "response body should not contain #{text.inspect}"
  end
end
