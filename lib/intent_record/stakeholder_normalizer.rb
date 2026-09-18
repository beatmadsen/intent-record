require "uri"

module IntentRecord
  # Normalises stakeholder system names and source URIs so the same ticket is one source.
  module StakeholderNormalizer
    module_function

    def system_name(raw)
      raw.strip.downcase.gsub(/[\s_]+/, "-")
    end

    def uri(raw)
      value = raw.strip
      parsed = URI.parse(value)
      return value.chomp("/") unless parsed.is_a?(URI::Generic) && parsed.host

      downcased_authority(parsed).to_s.chomp("/")
    rescue URI::InvalidURIError
      value
    end

    def downcased_authority(parsed)
      normalized = parsed.dup
      normalized.scheme = normalized.scheme.downcase if normalized.scheme
      normalized.host = normalized.host.downcase
      normalized
    end
  end
end
