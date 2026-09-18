require "active_record"
require "active_record/connection_adapters/sqlite3_adapter"

# A SELECT without an ORDER BY promises nothing about row order. SQLite answers
# one today in insertion order because that is what the plan it picked happens to
# produce; an index added later, or a different version of the planner, is free
# to answer another. So a test that asserts on the order of an unordered query is
# green for a reason it did not earn, and the day it turns red the change that
# broke it will look unrelated.
#
# This lane reverses the rows of every unordered result, which is as legal an
# answer as the one SQLite gave. A test that survives both has pinned the order
# itself; one that does not was reading the plan's mind. Reversal rather than a
# shuffle, because a lane that decides something different each run cannot be
# debugged, and would be a source of exactly the non-determinism it hunts.
module UnorderedRows
  ENV_FLAG = "CHAOS_UNORDERED_ROWS".freeze

  # Counted so the lane can be asked whether it did anything. A chaos lane that
  # silently reversed nothing would report green and guard nothing.
  @reversed = 0

  class << self
    attr_reader :reversed

    def record_reversal
      @reversed += 1
    end

    def enabled?
      !ENV[ENV_FLAG].to_s.empty?
    end

    def install!
      ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(Reversing)
    end
  end

  module Reversing
    ORDERED = /\border\s+by\b/i

    def internal_exec_query(sql, ...)
      result = super
      return result unless UnorderedRows.reversible?(sql, result)

      UnorderedRows.record_reversal
      ActiveRecord::Result.new(result.columns, result.rows.reverse, result.column_types)
    end
  end

  def self.reversible?(sql, result)
    return false unless sql.is_a?(String) && sql.lstrip[0, 6].casecmp("select").zero?
    return false if sql.match?(Reversing::ORDERED)

    result.respond_to?(:rows) && result.rows.size > 1
  end
end

UnorderedRows.install! if UnorderedRows.enabled?
