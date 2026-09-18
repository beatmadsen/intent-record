require_relative "../../commands/search"

module IntentRecord
  module Web
    module Routes
      module Search
        def self.registered(app)
          app.get "/search" do
            terms = params[:q].to_s.split
            results = terms.empty? ? [] : Commands::Search.new(terms: terms, match: "all").call["intents"]
            erb :search, locals: { query: params[:q].to_s, intents: results }
          end
        end
      end
    end
  end
end
