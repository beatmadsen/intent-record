require_relative "../../commands/by_source"

module IntentRecord
  module Web
    module Routes
      module Sources
        def self.registered(app)
          app.get "/sources" do
            uri = params[:uri].to_s
            intents = uri.strip.empty? ? [] : Commands::BySource.new(uri: uri, contains: true).call["intents"]
            erb :sources, locals: { uri: uri, intents: intents }
          end
        end
      end
    end
  end
end
