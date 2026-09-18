$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "intent_record"

require "minitest/autorun"
require "fileutils"
require "tmpdir"

# Mutation testing already forks a worker per mutant. Forking again here would
# multiply processes until the machine runs out of memory, so the mutation lane
# sets MUTATION_TESTING and takes the serial executor.
unless ENV["MUTATION_TESTING"]
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
