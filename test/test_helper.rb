$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "intent_record"

require "minitest/autorun"
require "fileutils"
require "tmpdir"

# Every test makes its own directory and hands it to Config, but that is a
# convention, and a convention only holds while every caller remembers it. Lose
# the config_dir argument, through a bug or through a mutant, and Config falls
# back to ~/.intent-record: the store the person running the suite actually
# keeps their work in. That has happened. So make production unreachable from a
# test process rather than merely unused by one, by pointing both fallbacks at a
# sandbox. The sandbox then has to stay empty, because anything landing in it is
# a test that skipped its own directory and is sharing state with every other
# test that did the same. TEST_SANDBOX_HOME checks that at exit.
module TestSandbox
  # One fixed path rather than a fresh temporary directory per process. The
  # mutation lane runs the suite in a process per mutant, and those reach neither
  # minitest's exit hook nor at_exit, so a per-process directory accumulated one
  # empty leftover per mutant: measured, a thousand of them in an afternoon. A
  # fixed path cannot accumulate.
  HOME = File.join(Dir.tmpdir, "intent-record-test-sandbox")

  # Emptied on the way in, because a breach from an earlier run is not this
  # run's to report. Under the mutation lane several processes load this at
  # once, so in principle one could clear evidence another just wrote; nothing
  # writes here legitimately, and the cost is a missed report rather than a
  # missed guard, since the fallback still lands here and not in the real store.
  def self.install!
    FileUtils.rm_rf(HOME)
    FileUtils.mkdir_p(HOME)
    ENV["INTENT_RECORD_CONFIG_DIR"] = HOME
    IntentRecord::Config.send(:remove_const, :DEFAULT_CONFIG_DIR)
    IntentRecord::Config.const_set(:DEFAULT_CONFIG_DIR, HOME)
  end

  def self.in_effect?
    IntentRecord::Config.default.config_dir == HOME
  end

  def self.entries
    Dir.children(HOME)
  rescue Errno::ENOENT
    []
  end

  # Clears what it found, so the breach is reported against the test that caused
  # it rather than cascading into every test that runs after it.
  def self.breach
    used = entries
    return nil if used.empty?

    used.each { |entry| FileUtils.rm_rf(File.join(HOME, entry)) }
    "wrote #{used.join(", ")} to the shared sandbox instead of its own config dir"
  end

  # A failure inside an at_exit hook is not a test failure: the runner has
  # already reported, and a mutation run reads it as a mutant that could not be
  # evaluated rather than one that was caught. So the check belongs after each
  # test, where it fails like anything else.
  module Guard
    # Before the test body, so a sandbox that failed to install stops the test
    # rather than being noticed once it has already written somewhere. Checking
    # here instead of at load time also keeps it legible to the mutation lane: a
    # crash while the file is being required is a mutant the runner cannot
    # classify, where a failing test is one it counts as caught.
    def before_setup
      super
      return if TestSandbox.in_effect?

      flunk "the test sandbox is not in effect, so a test could reach the real store"
    end

    def after_teardown
      super
      breach = TestSandbox.breach
      flunk("#{name} #{breach}. Give it its own config dir; the fallback is not for tests.") if breach
    end
  end
end

TestSandbox.install!
Minitest::Test.include(TestSandbox::Guard)
# at_exit rather than Minitest.after_run: the mutation lane runs the suite in a
# process per mutant, and those do not reach minitest's own exit hook, so each
# one left its sandbox behind. A thousand empty directories is only litter, but
# litter in the place the suite uses to prove it stayed out of the real store.

# Mutation testing already forks a worker per mutant. Forking again here would
# multiply processes until the machine runs out of memory, so a mutation run
# takes the serial executor. The Mutineer constant covers a direct `mutineer
# run`; MUTATION_TESTING covers the workers it forks to run the suite.
unless ENV["MUTATION_TESTING"] || defined?(Mutineer)
  begin
    require "active_support/testing/parallelization"
    require "active_support/testing/parallelize_executor"
    require "concurrent"

    Minitest.parallel_executor = ActiveSupport::Testing::ParallelizeExecutor.new(
      size: Concurrent.processor_count,
      with: :processes,
      threshold: 0
    )
  rescue LoadError, NameError
    nil
  end
end

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }
