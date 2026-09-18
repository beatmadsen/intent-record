require "test_helper"
require "minitest/mock"
require "intent_record/web/app"

# The 404 and 400 handlers are covered by the pages that raise those naturally.
# Nothing raises anything else, so the catch-all was the one error page never
# rendered, and a broken template there would only ever be seen by a user.
class ErrorPageTest < WebAcceptanceCase
  BOOM = ->(**) { raise "the database went away" }

  def test_an_unexpected_failure_renders_the_error_page_rather_than_crashing
    IntentRecord::Commands::Recent.stub(:new, BOOM) { get_home }

    assert_equal 500, last_response.status
    assert_body_includes "Something went wrong"
  end

  def test_an_unexpected_failure_is_logged_for_whoever_is_running_serve
    errors = StringIO.new

    IntentRecord::Commands::Recent.stub(:new, BOOM) { get_home(errors) }

    assert_match(/the database went away/, errors.string)
  end

  private

  # Rack hands every request its own error stream, so nothing here has to reach
  # for a global one.
  def get_home(errors = StringIO.new)
    get "/", {}, "rack.errors" => errors
  end
end
