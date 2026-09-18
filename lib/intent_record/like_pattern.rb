require "active_record"

module IntentRecord
  # Builds case-insensitive, literal-safe LIKE fragments. SQLite only honours the escape
  # character when an ESCAPE clause is present, so every LIKE goes through here.
  module LikePattern
    ESCAPE = "ESCAPE '\\'".freeze

    module_function

    def contains(column)
      "ULOWER(#{column}) LIKE ? #{ESCAPE}"
    end

    def contains_bind(term)
      "%#{escape(term.downcase)}%"
    end

    def prefix(column)
      "#{column} LIKE ? #{ESCAPE}"
    end

    def prefix_bind(term)
      "#{escape(term)}%"
    end

    def escape(term)
      ActiveRecord::Base.sanitize_sql_like(term)
    end

    # A step of the two binds, not part of what this module offers callers.
    private_class_method :escape
  end
end
