require_relative "../../commands/by_source"

module IntentRecord
  module Web
    module Routes
      module Sources
        EMPTY = { "intents" => [], "asset_versions" => [] }.freeze

        def self.registered(app)
          app.get "/sources" do
            uri = params[:uri].to_s
            result = uri.strip.empty? ? EMPTY : Commands::BySource.new(uri: uri, contains: true).call
            erb :sources, locals: { uri: uri, intents: result["intents"], versions: result["asset_versions"] }
          end
        end
      end
    end
  end
end
