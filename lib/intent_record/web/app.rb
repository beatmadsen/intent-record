require "sinatra/base"
require "erb"
require_relative "query_router"
require_relative "routes/home"
require_relative "routes/commits"
require_relative "routes/intents"
require_relative "routes/search"
require_relative "routes/sources"

module IntentRecord
  module Web
    # Read-only local GUI. Expects the database to be connected before requests arrive.
    class App < Sinatra::Base
      set :host_authorization, { permitted_hosts: [] }
      set :views, File.expand_path("views", __dir__)
      set :public_folder, File.expand_path("public", __dir__)
      set :static, true
      set :show_exceptions, false
      set :dump_errors, false

      helpers do
        def h(text)
          ERB::Util.html_escape(text)
        end

        def intent_cards(records)
          erb :_intent_cards, locals: { records: records }
        end
      end

      error NotFoundError do
        status 404
        erb :error, locals: { title: "Not found", message: env["sinatra.error"].message }
      end

      error ValidationError do
        status 400
        erb :error, locals: { title: "Cannot answer that", message: env["sinatra.error"].message }
      end

      error StandardError do
        status 500
        warn "#{env["sinatra.error"].class}: #{env["sinatra.error"].message}"
        erb :error, locals: { title: "Something went wrong", message: env["sinatra.error"].message }
      end

      register Routes::Home
      register Routes::Commits
      register Routes::Intents
      register Routes::Search
      register Routes::Sources
    end
  end
end
