# Counts the SQL a block issues, so a test can assert that work does not grow
# per record. SCHEMA statements are left out: they are the adapter reading the
# table definitions, not the query under test.
module QueryCounting
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

Minitest::Test.include(QueryCounting)
