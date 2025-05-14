require "kemal"
require "json"
require "log"
require "../../config"
require "../../lib/couchdb"
require "../../lib/dragonfly"
require "../../models/user"
require "./middlewares/database_auth"
require "./routing/*"

module Comixone::Api
  VERSION = "0.1.0"
  Log     = ::Log.for(self)

  class Application
    property config : Comixone::Config
    property couchdb : Comixone::Lib::CouchDB
    property dragonfly : Comixone::Lib::Dragonfly
    property name : String = "comixone-api"

    def initialize
      @config = Comixone::Config.load

      # Set up logging
      setup_logging

      Log.info { "Initializing Comixone API application" }

      @couchdb = Comixone::Lib::CouchDB.new(@config.couchdb)
      @dragonfly = Comixone::Lib::Dragonfly.new(@config.dragonfly)
    end

    def init
      # Configure Kemal
      configure_kemal

      # Add CORS middleware
      add_cors_handler

      # Add database authentication middleware
      add_database_auth_handler

      # Add JWT authentication if enabled
      add_jwt_auth_handler if @config.api.auth.jwt.enabled

      # Set up content type for API routes
      before_all "/api/*" do |env|
        env.response.content_type = "application/json"
      end

      # Add request logging middleware if enabled
      add_request_logging if @config.logging.log_requests

      # Set up routes via the routing registry
      Routing::Registry.setup(self)

      Log.info { "Comixone API initialized successfully" }
    end

    def run
      Log.info { "Starting Comixone API server on port #{@config.server.port}" }
      Kemal.run(@config.server.port)
    end

    private def setup_logging
      # Configure the logging based on config
      backend = case @config.logging.output.downcase
                when "stdout"
                  Log::IOBackend.new(STDOUT)
                when "stderr"
                  Log::IOBackend.new(STDERR)
                else
                  # File output
                  file = File.open(@config.logging.output, "a+")
                  Log::IOBackend.new(file)
                end

      # Set the format
      if @config.logging.format.downcase == "json"
        backend.formatter = Log::JsonFormatter.new
      else
        backend.formatter = Log::Formatter.new do |entry, io|
          io << entry.timestamp.to_s("%Y-%m-%d %H:%M:%S") << " [" << entry.severity << "] "
          io << entry.context.to_s << ": " if entry.context
          io << entry.message
          if entry.data
            io << " -- " << entry.data
          end
        end
      end

      Log.setup(@config.log_level, backend)
    end

    private def configure_kemal
      # Set server options
      Kemal.config.env = @config.server.environment

      # Set request timeouts
      if @config.production?
        Kemal.config.server_handler = HTTP::Server::RequestProcessor.new do |context|
          # Set timeout for request processing
          context.response.headers["X-Request-Timeout"] = @config.api.request_timeout.to_s

          # Set up compression if enabled
          if @config.api.enable_compression
            context.response.headers["Content-Encoding"] = "gzip"
          end
        end
      end
    end

    private def add_cors_handler
      Log.debug { "Adding CORS handler with origins: #{@config.api.cors.allowed_origins}" }
      add_handler CORS.new(@config.api.cors)
    end

    private def add_database_auth_handler
      Log.debug { "Adding Database Auth handler" }
      add_handler DatabaseAuth.new(self)
    end

    private def add_jwt_auth_handler
      Log.debug { "Adding JWT Auth handler" }
      add_handler JwtAuth.new(self)
    end

    private def add_request_logging
      Log.debug { "Adding request logging middleware" }

      before_all do |env|
        # Record start time
        env.set "start_time", Time.monotonic
      end

      after_all do |env|
        # Skip internal Kemal routes
        unless env.request.path.starts_with?("/__kemal")
          # Calculate request duration
          start_time = env.get("start_time").as(Time::Span)
          duration_ms = (Time.monotonic - start_time).total_milliseconds

          # Get authenticated user if available
          user_info = if user = env.get?("current_user").try(&.as(Comixone::Models::User))
                        " (User: #{user.email})"
                      else
                        ""
                      end

          # Log the request
          Log.info { "#{env.request.method} #{env.request.path} - #{env.response.status_code} (#{duration_ms.round(2)}ms)#{user_info}" }
        end
      end
    end
  end

  # CORS middleware
  class CORS < Kemal::Handler
    def initialize(@config : Comixone::Config::CorsConfig)
    end

    def call(env)
      env.response.headers["Access-Control-Allow-Origin"] = @config.allowed_origins
      env.response.headers["Access-Control-Allow-Methods"] = @config.allowed_methods
      env.response.headers["Access-Control-Allow-Headers"] = @config.allowed_headers
      env.response.headers["Access-Control-Expose-Headers"] = @config.expose_headers
      env.response.headers["Access-Control-Max-Age"] = @config.max_age.to_s

      if @config.allow_credentials
        env.response.headers["Access-Control-Allow-Credentials"] = "true"
      end

      if env.request.method == "OPTIONS"
        env.response.status_code = 200
        env.response.close
      else
        call_next(env)
      end
    end
  end

  def self.new
    Application.new
  end
end
