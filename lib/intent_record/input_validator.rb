module IntentRecord
  # Shape checks for the JSON an agent sends on stdin. Raises ValidationError with a field-named message.
  module InputValidator
    module_function

    def required_string!(input, key, max_length: nil)
      value = non_blank_string!(input, key)
      max_length ? within_length!(value, key, max_length) : value
    end

    def optional_string!(input, key)
      value = input[key]
      return nil if value.nil?
      raise ValidationError, "#{key} must be a string" unless value.is_a?(String)

      value = value.strip
      value.empty? ? nil : value
    end

    def array!(input, key)
      value = input[key]
      return [] if value.nil?
      raise ValidationError, "#{key} must be an array" unless value.is_a?(Array)

      value
    end

    def non_blank_strings!(values, label)
      values.each do |v|
        raise ValidationError, "#{label} must be a non-empty string" unless v.is_a?(String) && !v.strip.empty?
      end
      values
    end

    def hashes_with!(values, label, *keys)
      values.each do |v|
        raise ValidationError, "#{label} entries must be objects" unless v.is_a?(Hash)

        keys.each { |k| required_string!(v, k) }
      end
      values
    end

    def non_blank_string!(input, key)
      value = input[key]
      raise ValidationError, "#{key} is required" if value.nil?
      raise ValidationError, "#{key} must be a string" unless value.is_a?(String)

      value = value.strip
      raise ValidationError, "#{key} cannot be blank" if value.empty?

      value
    end

    def within_length!(value, key, max_length)
      raise ValidationError, "#{key} must be #{max_length} characters or fewer" if value.length > max_length

      value
    end

    # Steps of required_string!, not part of what this module offers callers.
    private_class_method :non_blank_string!, :within_length!
  end
end
