require "test_helper"

# Minting the global id means asking the database whether that id is already
# taken. Doing it while building the attributes put that query ahead of the
# validation, so invalid input was checked against the store before being
# refused, and the rules could not be exercised without one.
class RecordRejectsBeforeTouchingTheDatabaseTest < Minitest::Test
  include DbTestSetup

  def test_input_missing_a_summary_is_refused_without_a_query
    assert_empty(queries_while { refuses("body" => "b") })
  end

  def test_input_missing_a_body_is_refused_without_a_query
    assert_empty(queries_while { refuses("summary" => "s") })
  end

  # Without this the two above would also pass on a Record that never queried at
  # all, so the measurement has to be shown capable of seeing a query.
  def test_input_that_is_accepted_does_query
    refute_empty(queries_while { record("summary" => "s", "body" => "b") })
  end

  private

  def record(input)
    IntentRecord::Commands::Record.new.call(input)
  end

  def refuses(input)
    assert_raises(IntentRecord::ValidationError) { record(input) }
  end

  def queries_while(&)
    seen = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      seen << payload[:sql] unless payload[:name] == "SCHEMA"
    end
    collecting(subscriber, &)
    seen
  end

  def collecting(subscriber)
    yield
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
