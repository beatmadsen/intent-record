require "socket"

# A test that listens on a port leaves something behind after the run and can
# block the run indefinitely: a probe that made `serve` really start left a Puma
# on 4791 and hung the suite until it was killed by hand. Only one test drives
# `serve` for real, and it does so expecting the bind to fail, so binding is
# refused here unless a test says it means to.
#
# Stub Web::App.run! if a test reaches `serve` without caring about the server,
# which is what every test but ServeTest wants.
module PortConfinement
  class Escape < StandardError; end

  @allowed = false

  class << self
    attr_reader :allowed

    # Process-wide rather than thread-local on purpose: the suite is parallel by
    # process, and the bind happens somewhere inside Puma rather than in the
    # thread that asked for it.
    def binding_a_port
      previous = @allowed
      @allowed = true
      yield
    ensure
      @allowed = previous
    end

    def check!(host, port)
      return if @allowed

      raise Escape, "refusing to listen on #{host}:#{port}: a test must not bind a port. " \
                    "Stub IntentRecord::Web::App.run!, or wrap a deliberate bind in " \
                    "PortConfinement.binding_a_port."
    end

    def installed?
      TCPServer.ancestors.include?(TCPServerGuard)
    end
  end

  module TCPServerGuard
    def initialize(*args, **, &)
      host, port = args.size > 1 ? args : [nil, args.first]
      PortConfinement.check!(host, port)
      super
    end
  end

  module Guard
    def before_setup
      super
      return if PortConfinement.installed?

      flunk "port confinement is not installed, so a test could leave a server running"
    end
  end
end

TCPServer.prepend(PortConfinement::TCPServerGuard)
Minitest::Test.include(PortConfinement::Guard)
