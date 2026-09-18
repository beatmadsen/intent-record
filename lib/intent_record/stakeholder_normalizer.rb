require "uri"

module IntentRecord
  # Normalises stakeholder system names and source URIs so the same ticket is one source.
  module StakeholderNormalizer
    module_function

    def system_name(raw)
      raw.strip.downcase.gsub(/[\s_]+/, "-")
    end

    # A value with neither scheme nor host is an opaque identifier such as a bare
    # ticket key, and case is significant there. Anything else is a URI, whose
    # scheme URI.parse has already downcased for us; only the host is left to do.
    def uri(raw)
      value = raw.strip
      parsed = URI.parse(value)
      return value.chomp("/") unless parsed.scheme || parsed.host

      downcased_host(parsed).to_s.chomp("/")
    rescue URI::InvalidURIError
      value
    end

    def downcased_host(parsed)
      return parsed unless parsed.host

      normalized = parsed.dup
      normalized.host = parsed.host.downcase
      normalized
    end
  end
end
