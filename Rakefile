require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = false
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

desc "Mutation testing over lib; fails below the threshold in .mutineer.yml"
task :mutation do
  tests = FileList["test/**/*_test.rb"].flat_map { |file| ["--test", file] }
  sources = FileList["lib/**/*.rb"].exclude(UNMUTATABLE)
  sh({ "MUTATION_TESTING" => "1", "RUBYOPT" => "-Ilib -Itest" },
     "bundle", "exec", "mutineer", "run",
     *sources, *tests, "--strategy", "redefine")
end

task default: %i[test rubocop]
