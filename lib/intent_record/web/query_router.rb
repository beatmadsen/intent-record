require "uri"

module IntentRecord
  module Web
    # Decides where a free-text query from the home page search box should go.
    module QueryRouter
      HEX = /\A[0-9a-f]{4,}\z/i

      module_function

      def path_for(raw)
        query = raw.to_s.strip
        return "/" if query.empty?
        return "/commits/#{query}" if HEX.match?(query)
        return "/sources?uri=#{URI.encode_www_form_component(query)}" if url?(query)

        "/search?q=#{URI.encode_www_form_component(query)}"
      end

      def url?(query)
        query.match?(%r{\A[a-z][a-z0-9+.-]*://}i)
      end
    end
  end
end
