require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

def test_task(name)
  Rake::TestTask.new(name) do |t|
    t.libs << "test"
    t.libs << "lib"
    t.test_files = FileList["test/**/*_test.rb"]
    t.verbose = false
  end
end

test_task(:test)

namespace :test do
  # The same suite, with the rows of every query that does not name its order
  # reversed. SQL promises nothing about the order of those, and SQLite already
  # answers some of them from an index rather than in insertion order, so a test
  # that agrees with today's plan has proven nothing about tomorrow's. See
  # test/support/unordered_rows.rb. It runs in the default gate because a lane
  # that is only opt-in is a lane nobody runs.
  task :chaos_rows do
    ENV["CHAOS_UNORDERED_ROWS"] = "1"
  end

  test_task(:chaos_run)

  desc "The suite again, with every unordered query answered backwards"
  task chaos: %i[chaos_rows chaos_run]
end

RuboCop::RakeTask.new

# Sinatra installs a route's body on the app class when the module is registered,
# which happens once at boot, before mutineer forks. Neither the redefine nor the
# reload strategy can reach a block that is already captured, so every mutant in a
# route file is reported as surviving when no test could possibly kill it. Making
# the same edits by hand does turn the web acceptance tests red, so the behaviour
# is covered; only the measurement is impossible. False survivors teach people to
# skim the report, so these files stay out of it.
UNMUTATABLE = "lib/intent_record/web/routes/*.rb".freeze

def mutineer(*extra)
  tests = FileList["test/**/*_test.rb"].flat_map { |file| ["--test", file] }
  sources = FileList["lib/**/*.rb"].exclude(UNMUTATABLE)
  sh({ "MUTATION_TESTING" => "1", "RUBYOPT" => "-Ilib -Itest" },
     "bundle", "exec", "mutineer", "run",
     *sources, *tests, "--strategy", "redefine", *extra)
end

desc "Mutation testing over lib; fails below the threshold in .mutineer.yml"
task :mutation do
  mutineer
end

namespace :mutation do
  # The full lane takes about half a minute of wall clock against two seconds for
  # `rake`, which is why it is not part of the default gate. This is the quick
  # version for the edit loop: only the lines you have not committed yet. It is a
  # prompt to look, not a verdict, because a scoped run is small enough that one
  # equivalent mutant sinks the score. `rake mutation` remains the verdict.
  desc "Mutation testing over uncommitted changes only"
  task :changed do
    mutineer("--since", "HEAD")
  end
end

task default: %i[test test:chaos rubocop]
