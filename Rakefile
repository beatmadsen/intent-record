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

desc "Mutation testing over lib; fails below the threshold in .mutineer.yml"
task :mutation do
  tests = FileList["test/**/*_test.rb"].flat_map { |file| ["--test", file] }
  sh({ "MUTATION_TESTING" => "1", "RUBYOPT" => "-Ilib -Itest" },
     "bundle", "exec", "mutineer", "run",
     *FileList["lib/**/*.rb"], *tests, "--strategy", "redefine")
end

task default: %i[test rubocop]
