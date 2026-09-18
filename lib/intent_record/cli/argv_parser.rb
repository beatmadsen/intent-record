module IntentRecord
  class CLI
    # Owns the arguments it is given and consumes them: each `take_*` removes what
    # it matched, so `reject_leftovers!` can then judge whatever nobody claimed.
    # The caller's own array is never touched. Options may be given as
    # `--name value` or `--name=value`.
    class ArgvParser
      def initialize(argv)
        @argv = argv.dup
      end

      # What is left unconsumed, for a caller that forwards its arguments on
      # rather than judging them here.
      def remaining
        @argv.dup
      end

      def take_flag(name)
        indexes = @argv.each_index.select { |i| @argv[i] == name || @argv[i].start_with?("#{name}=") }
        raise ValidationError, "#{name} given more than once" if indexes.size > 1
        return nil if indexes.empty?

        extract_flag(indexes.first, name)
      end

      def take_integer_flag(name, default)
        raw = take_flag(name)
        return default if raw.nil?
        raise ValidationError, "#{name} requires an integer, got #{raw.inspect}" unless /\A\d+\z/.match?(raw)

        raw.to_i
      end

      def take_required_positional(label)
        value = @argv.shift
        raise ValidationError, "#{label} is required" if value.nil? || value.strip.empty?

        value
      end

      # Everything that is not an option. The options are kept, so
      # reject_leftovers! still judges them.
      def take_positionals
        options, positionals = @argv.partition { |token| token.start_with?("--") }
        @argv.replace(options)
        positionals
      end

      def take_switch?(name)
        !@argv.delete(name).nil?
      end

      def reject_leftovers!
        return if @argv.empty?

        raise ValidationError, "Unexpected argument(s): #{@argv.join(" ")}"
      end

      private

      # A flag whose value is missing is deliberately left in place rather than
      # consumed, so that it reaches reject_leftovers! as an error instead of
      # passing for a value nobody gave.
      def extract_flag(idx, name)
        token = @argv[idx]
        return @argv.delete_at(idx).delete_prefix("#{name}=") if token.include?("=")
        return nil unless @argv[idx + 1] && !@argv[idx + 1].start_with?("--")

        value = @argv[idx + 1]
        @argv.slice!(idx, 2)
        value
      end
    end
  end
end
