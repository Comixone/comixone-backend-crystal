require "yaml"
require "file"
require "log"

# Set up a simple default logger
Log.setup(:info, Log::IOBackend.new)

module Comixone
  class Config
    # =========== Simple configuration classes ===========

    # Server configuration
    class ServerConfig
      property host : String
      property port : Int32
      property environment : String

      def initialize(@host = "127.0.0.1", @port = 3000, @environment = "development")
      end
    end

    # CouchDB configuration
    class CouchDBConfig
      property url : String
      property username : String
      property password : String
      property database : String
      property connect_timeout : Int32
      property request_timeout : Int32
      property retry_count : Int32
      property retry_wait : Int32
      property create_if_missing : Bool
      property auto_update_design_docs : Bool

      def initialize(
        @url = "http://localhost:5984",
        @username = "comixone",
        @password = "comixone",
        @database = "comixone",
        @connect_timeout = 30,
        @request_timeout = 30,
        @retry_count = 3,
        @retry_wait = 1,
        @create_if_missing = true,
        @auto_update_design_docs = true,
      )
      end
    end

    # Dragonfly configuration
    class DragonflyConfig
      property url : String
      property password : String?
      property database : Int32
      property connect_timeout : Float64
      property read_timeout : Float64
      property write_timeout : Float64
      property max_retries : Int32
      property retry_interval : Float64

      def initialize(
        @url = "redis://localhost:6379",
        @password = nil,
        @database = 0,
        @connect_timeout = 5.0,
        @read_timeout = 5.0,
        @write_timeout = 5.0,
        @max_retries = 3,
        @retry_interval = 0.1,
      )
      end
    end

    # Basic Auth config
    class BasicAuthConfig
      property enabled : Bool
      property users : Hash(String, String)

      def initialize(@enabled = true, @users = {"comixone" => "comixone"})
      end
    end

    # JWT Auth config
    class JwtConfig
      property enabled : Bool
      property secret : String
      property algorithm : String
      property expiration : Int32

      def initialize(
        @enabled = false,
        @secret = "Qbtkbm%0sV##5qeNXk5vFHDXjMd^*JhW",
        @algorithm = "HS256",
        @expiration = 86400,
      )
      end
    end

    # Auth config
    class AuthConfig
      property basic : BasicAuthConfig
      property jwt : JwtConfig

      def initialize(
        @basic = BasicAuthConfig.new,
        @jwt = JwtConfig.new,
      )
      end
    end

    # CORS configuration
    class CorsConfig
      property allowed_origins : String
      property allowed_methods : String
      property allowed_headers : String
      property expose_headers : String
      property allow_credentials : Bool
      property max_age : Int32

      def initialize(
        @allowed_origins = "*",
        @allowed_methods = "GET, POST, PUT, DELETE, OPTIONS",
        @allowed_headers = "Content-Type, Authorization",
        @expose_headers = "Content-Length, Content-Type",
        @allow_credentials = false,
        @max_age = 7200,
      )
      end
    end

    # API configuration
    class ApiConfig
      property cors : CorsConfig
      property auth : AuthConfig
      property rate_limit : Bool
      property rate_limit_requests : Int32
      property request_timeout : Int32
      property enable_compression : Bool

      def initialize(
        @cors = CorsConfig.new,
        @auth = AuthConfig.new,
        @rate_limit = false,
        @rate_limit_requests = 100,
        @request_timeout = 30,
        @enable_compression = true,
      )
      end
    end

    # Job configuration
    class JobConfig
      property enabled : Bool
      property interval : Int32
      property retries : Int32
      property retry_wait : Int32
      property timeout : Int32

      def initialize(
        @enabled = true,
        @interval = 3600,
        @retries = 3,
        @retry_wait = 60,
        @timeout = 300,
      )
      end
    end

    # Jobs configuration
    class JobsConfig
      property cleanup : JobConfig
      property notifications : JobConfig

      def initialize(
        @cleanup = JobConfig.new,
        @notifications = JobConfig.new,
      )
      end
    end

    # Workers configuration
    class WorkersConfig
      property jobs : JobsConfig
      property worker_threads : Int32
      property max_queue_size : Int32

      def initialize(
        @jobs = JobsConfig.new,
        @worker_threads = 4,
        @max_queue_size = 1000,
      )
      end
    end

    # Logging configuration
    class LoggingConfig
      property level : String
      property format : String
      property output : String
      property log_requests : Bool

      def initialize(
        @level = "info",
        @format = "text",
        @output = "stdout",
        @log_requests = true,
      )
      end
    end

    # =========== Main configuration class ===========

    # Main properties
    property server : ServerConfig
    property couchdb : CouchDBConfig
    property dragonfly : DragonflyConfig
    property api : ApiConfig
    property workers : WorkersConfig
    property logging : LoggingConfig

    def initialize
      @server = ServerConfig.new
      @couchdb = CouchDBConfig.new
      @dragonfly = DragonflyConfig.new
      @api = ApiConfig.new
      @workers = WorkersConfig.new
      @logging = LoggingConfig.new
    end

    # =========== Configuration loading ===========

    # Load configuration from file with environment variable overrides
    def self.load(path : String = "config.yaml") : Config
      # Start with a default config
      config = Config.new

      # Load from file if exists
      if File.exists?(path)
        begin
          Log.debug { "Loading configuration from #{path}" }
          yaml_content = File.read(path)

          # Parse YAML
          yaml_config = YAML.parse(yaml_content)
          apply_yaml_config(config, yaml_config)

          Log.info { "Configuration loaded from #{path}" }
        rescue ex
          Log.error(exception: ex) { "Error reading config file: #{path}" }
          Log.warn { "Using default configuration" }
          # Keep using the default config
        end
      else
        Log.warn { "Config file not found: #{path}, using defaults" }
      end

      # Override with environment variables if set
      override_from_env(config)

      # Set up logging based on config
      setup_logging(config)

      config
    end

    # Apply YAML configuration to a config object
    private def self.apply_yaml_config(config, yaml)
      # Parse server config
      if server_yaml = yaml["server"]?
        if host = server_yaml["host"]?.try(&.as_s?)
          config.server.host = host
        end

        if port = server_yaml["port"]?.try(&.as_i?)
          config.server.port = port
        end

        if env = server_yaml["environment"]?.try(&.as_s?)
          config.server.environment = env
        end
      end

      # Parse CouchDB config
      if couchdb_yaml = yaml["couchdb"]?
        if url = couchdb_yaml["url"]?.try(&.as_s?)
          config.couchdb.url = url
        end

        if username = couchdb_yaml["username"]?.try(&.as_s?)
          config.couchdb.username = username
        end

        if password = couchdb_yaml["password"]?.try(&.as_s?)
          config.couchdb.password = password
        end

        if database = couchdb_yaml["database"]?.try(&.as_s?)
          config.couchdb.database = database
        end

        if connect_timeout = couchdb_yaml["connect_timeout"]?.try(&.as_i?)
          config.couchdb.connect_timeout = connect_timeout
        end

        if request_timeout = couchdb_yaml["request_timeout"]?.try(&.as_i?)
          config.couchdb.request_timeout = request_timeout
        end

        if retry_count = couchdb_yaml["retry_count"]?.try(&.as_i?)
          config.couchdb.retry_count = retry_count
        end

        if retry_wait = couchdb_yaml["retry_wait"]?.try(&.as_i?)
          config.couchdb.retry_wait = retry_wait
        end

        if create_if_missing = couchdb_yaml["create_if_missing"]?.try(&.as_bool?)
          config.couchdb.create_if_missing = create_if_missing
        end

        if auto_update_design_docs = couchdb_yaml["auto_update_design_docs"]?.try(&.as_bool?)
          config.couchdb.auto_update_design_docs = auto_update_design_docs
        end
      end

      # Parse Dragonfly config
      if dragonfly_yaml = yaml["dragonfly"]?
        if url = dragonfly_yaml["url"]?.try(&.as_s?)
          config.dragonfly.url = url
        end

        if password = dragonfly_yaml["password"]?
          if password.raw.nil?
            config.dragonfly.password = nil
          elsif password_str = password.as_s?
            config.dragonfly.password = password_str.empty? ? nil : password_str
          end
        end

        if database = dragonfly_yaml["database"]?.try(&.as_i?)
          config.dragonfly.database = database
        end

        if connect_timeout = dragonfly_yaml["connect_timeout"]?.try(&.as_f?)
          config.dragonfly.connect_timeout = connect_timeout
        end

        if read_timeout = dragonfly_yaml["read_timeout"]?.try(&.as_f?)
          config.dragonfly.read_timeout = read_timeout
        end

        if write_timeout = dragonfly_yaml["write_timeout"]?.try(&.as_f?)
          config.dragonfly.write_timeout = write_timeout
        end

        if max_retries = dragonfly_yaml["max_retries"]?.try(&.as_i?)
          config.dragonfly.max_retries = max_retries
        end

        if retry_interval = dragonfly_yaml["retry_interval"]?.try(&.as_f?)
          config.dragonfly.retry_interval = retry_interval
        end
      end

      # Parse API config
      if api_yaml = yaml["api"]?
        # Parse CORS config
        if cors_yaml = api_yaml["cors"]?
          if allowed_origins = cors_yaml["allowed_origins"]?.try(&.as_s?)
            config.api.cors.allowed_origins = allowed_origins
          end

          if allowed_methods = cors_yaml["allowed_methods"]?.try(&.as_s?)
            config.api.cors.allowed_methods = allowed_methods
          end

          if allowed_headers = cors_yaml["allowed_headers"]?.try(&.as_s?)
            config.api.cors.allowed_headers = allowed_headers
          end

          if expose_headers = cors_yaml["expose_headers"]?.try(&.as_s?)
            config.api.cors.expose_headers = expose_headers
          end

          if allow_credentials = cors_yaml["allow_credentials"]?.try(&.as_bool?)
            config.api.cors.allow_credentials = allow_credentials
          end

          if max_age = cors_yaml["max_age"]?.try(&.as_i?)
            config.api.cors.max_age = max_age
          end
        end

        # Parse Auth config
        if auth_yaml = api_yaml["auth"]?
          # Parse Basic Auth config
          if basic_yaml = auth_yaml["basic"]?
            if enabled = basic_yaml["enabled"]?.try(&.as_bool?)
              config.api.auth.basic.enabled = enabled
            end

            if users_yaml = basic_yaml["users"]?
              new_users = {} of String => String

              users_yaml.as_h?.try do |users_hash|
                users_hash.each do |user, pass|
                  if username = user.as_s?
                    if password = pass.as_s?
                      new_users[username] = password
                    end
                  end
                end
              end

              config.api.auth.basic.users = new_users unless new_users.empty?
            end
          end

          # Parse JWT Auth config
          if jwt_yaml = auth_yaml["jwt"]?
            if enabled = jwt_yaml["enabled"]?.try(&.as_bool?)
              config.api.auth.jwt.enabled = enabled
            end

            if secret = jwt_yaml["secret"]?.try(&.as_s?)
              config.api.auth.jwt.secret = secret
            end

            if algorithm = jwt_yaml["algorithm"]?.try(&.as_s?)
              config.api.auth.jwt.algorithm = algorithm
            end

            if expiration = jwt_yaml["expiration"]?.try(&.as_i?)
              config.api.auth.jwt.expiration = expiration
            end
          end
        end

        if rate_limit = api_yaml["rate_limit"]?.try(&.as_bool?)
          config.api.rate_limit = rate_limit
        end

        if rate_limit_requests = api_yaml["rate_limit_requests"]?.try(&.as_i?)
          config.api.rate_limit_requests = rate_limit_requests
        end

        if request_timeout = api_yaml["request_timeout"]?.try(&.as_i?)
          config.api.request_timeout = request_timeout
        end

        if enable_compression = api_yaml["enable_compression"]?.try(&.as_bool?)
          config.api.enable_compression = enable_compression
        end
      end

      # Parse Workers config
      if workers_yaml = yaml["workers"]?
        if jobs_yaml = workers_yaml["jobs"]?
          # Parse Cleanup job config
          if cleanup_yaml = jobs_yaml["cleanup"]?
            if enabled = cleanup_yaml["enabled"]?.try(&.as_bool?)
              config.workers.jobs.cleanup.enabled = enabled
            end

            if interval = cleanup_yaml["interval"]?.try(&.as_i?)
              config.workers.jobs.cleanup.interval = interval
            end

            if retries = cleanup_yaml["retries"]?.try(&.as_i?)
              config.workers.jobs.cleanup.retries = retries
            end

            if retry_wait = cleanup_yaml["retry_wait"]?.try(&.as_i?)
              config.workers.jobs.cleanup.retry_wait = retry_wait
            end

            if timeout = cleanup_yaml["timeout"]?.try(&.as_i?)
              config.workers.jobs.cleanup.timeout = timeout
            end
          end

          # Parse Notifications job config
          if notifications_yaml = jobs_yaml["notifications"]?
            if enabled = notifications_yaml["enabled"]?.try(&.as_bool?)
              config.workers.jobs.notifications.enabled = enabled
            end

            if interval = notifications_yaml["interval"]?.try(&.as_i?)
              config.workers.jobs.notifications.interval = interval
            end

            if retries = notifications_yaml["retries"]?.try(&.as_i?)
              config.workers.jobs.notifications.retries = retries
            end

            if retry_wait = notifications_yaml["retry_wait"]?.try(&.as_i?)
              config.workers.jobs.notifications.retry_wait = retry_wait
            end

            if timeout = notifications_yaml["timeout"]?.try(&.as_i?)
              config.workers.jobs.notifications.timeout = timeout
            end
          end
        end

        if worker_threads = workers_yaml["worker_threads"]?.try(&.as_i?)
          config.workers.worker_threads = worker_threads
        end

        if max_queue_size = workers_yaml["max_queue_size"]?.try(&.as_i?)
          config.workers.max_queue_size = max_queue_size
        end
      end

      # Parse Logging config
      if logging_yaml = yaml["logging"]?
        if level = logging_yaml["level"]?.try(&.as_s?)
          config.logging.level = level
        end

        if format = logging_yaml["format"]?.try(&.as_s?)
          config.logging.format = format
        end

        if output = logging_yaml["output"]?.try(&.as_s?)
          config.logging.output = output
        end

        if log_requests = logging_yaml["log_requests"]?.try(&.as_bool?)
          config.logging.log_requests = log_requests
        end
      end
    end

    # Override config with environment variables
    private def self.override_from_env(config)
      # Server config
      config.server.port = ENV["PORT"].to_i if ENV["PORT"]?
      config.server.host = ENV["HOST"] if ENV["HOST"]?
      config.server.environment = ENV["ENVIRONMENT"] if ENV["ENVIRONMENT"]?

      # CouchDB config
      config.couchdb.url = ENV["COUCHDB_URL"] if ENV["COUCHDB_URL"]?
      config.couchdb.username = ENV["COUCHDB_USERNAME"] if ENV["COUCHDB_USERNAME"]?
      config.couchdb.password = ENV["COUCHDB_PASSWORD"] if ENV["COUCHDB_PASSWORD"]?
      config.couchdb.database = ENV["COUCHDB_DATABASE"] if ENV["COUCHDB_DATABASE"]?

      # Dragonfly config
      config.dragonfly.url = ENV["DRAGONFLY_URL"] if ENV["DRAGONFLY_URL"]?
      config.dragonfly.password = ENV["DRAGONFLY_PASSWORD"] if ENV["DRAGONFLY_PASSWORD"]?
      config.dragonfly.database = ENV["DRAGONFLY_DATABASE"].to_i if ENV["DRAGONFLY_DATABASE"]?

      # Logging config
      config.logging.level = ENV["LOG_LEVEL"] if ENV["LOG_LEVEL"]?

      # JWT config
      if ENV["JWT_SECRET"]?
        config.api.auth.jwt.secret = ENV["JWT_SECRET"]
        config.api.auth.jwt.enabled = true
      end

      Log.debug { "Configuration overridden with environment variables" }
    end

    # Set up logging based on config
    private def self.setup_logging(config)
      backend = case config.logging.output.downcase
                when "stdout"
                  Log::IOBackend.new(STDOUT)
                when "stderr"
                  Log::IOBackend.new(STDERR)
                else
                  # File output
                  begin
                    file = File.open(config.logging.output, "a+")
                    Log::IOBackend.new(file)
                  rescue ex
                    Log.error { "Failed to open log file: #{config.logging.output}, falling back to stdout" }
                    Log::IOBackend.new(STDOUT)
                  end
                end

      backend.formatter = Log::Formatter.new do |entry, io|
        io << Time.utc.to_s("%Y-%m-%d %H:%M:%S") << " [" << entry.severity << "] "
        io << entry.context.to_s << ": " if entry.context
        io << entry.message
        if entry.data
          io << " -- " << entry.data
        end
      end

      # Convert string level to Log::Severity
      level = case config.logging.level.downcase
              when "debug"
                Log::Severity::Debug
              when "info"
                Log::Severity::Info
              when "notice"
                Log::Severity::Notice
              when "warn", "warning"
                Log::Severity::Warn
              when "error"
                Log::Severity::Error
              when "fatal", "critical"
                Log::Severity::Fatal
              else
                Log::Severity::Info
              end

      # Set up logging with configured level
      Log.setup(level, backend)
    end

    # Instance helpers

    # Check if we're in development mode
    def development?
      server.environment.downcase == "development"
    end

    # Check if we're in production mode
    def production?
      server.environment.downcase == "production"
    end

    # Check if we're in test mode
    def test?
      server.environment.downcase == "test"
    end

    # Convert string level to Log::Severity
    def log_level
      case logging.level.downcase
      when "debug"
        Log::Severity::Debug
      when "info"
        Log::Severity::Info
      when "notice"
        Log::Severity::Notice
      when "warn", "warning"
        Log::Severity::Warn
      when "error"
        Log::Severity::Error
      when "fatal", "critical"
        Log::Severity::Fatal
      else
        Log::Severity::Info
      end
    end
  end
end
