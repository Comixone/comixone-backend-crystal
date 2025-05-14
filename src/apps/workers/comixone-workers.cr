require "json"
require "log"
require "../../config"
require "../../lib/couchdb"
require "../../lib/dragonfly"
require "./jobs/*"

module Comixone::Workers
  VERSION = "0.1.0"
  Log     = ::Log.for(self)

  class Application
    property config : Comixone::Config
    property couchdb : Comixone::Lib::CouchDB
    property dragonfly : Comixone::Lib::Dragonfly
    property name : String = "comixone-workers"
    property running : Bool = false
    property jobs : Array(Job) = [] of Job

    def initialize
      @config = Comixone::Config.load

      # Set up logging
      setup_logging

      Log.info { "Initializing Comixone Workers application" }

      @couchdb = Comixone::Lib::CouchDB.new(@config.couchdb)
      @dragonfly = Comixone::Lib::Dragonfly.new(@config.dragonfly)
    end

    def init
      # Initialize all jobs
      init_jobs

      # Set up signal handlers for graceful shutdown
      setup_signal_handlers

      Log.info { "Comixone Workers initialized successfully" }
    end

    def run
      @running = true

      # Start all jobs
      @jobs.each(&.start)

      Log.info { "#{Time.utc}: Workers application started" }

      # Main loop
      while @running
        sleep(1.second)
      end

      # Stop all jobs
      @jobs.each(&.stop)

      Log.info { "#{Time.utc}: Workers application shutdown complete" }
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

    private def init_jobs
      # Register all background jobs
      if @config.workers.jobs.cleanup.enabled
        Log.info { "Registering cleanup job with interval #{@config.workers.jobs.cleanup.interval} seconds" }
        @jobs << Jobs::CleanupJob.new(
          self,
          @config.workers.jobs.cleanup.interval,
          @config.workers.jobs.cleanup.retries,
          @config.workers.jobs.cleanup.retry_wait,
          @config.workers.jobs.cleanup.timeout
        )
      end

      # Add more jobs as needed
      if @config.workers.jobs.notifications.enabled
        Log.info { "Registering notifications job with interval #{@config.workers.jobs.notifications.interval} seconds" }
        # @jobs << Jobs::NotificationJob.new(
        #   self,
        #   @config.workers.jobs.notifications.interval,
        #   @config.workers.jobs.notifications.retries,
        #   @config.workers.jobs.notifications.retry_wait,
        #   @config.workers.jobs.notifications.timeout
        # )
      end
    end

    private def setup_signal_handlers
      # Handle SIGINT (Ctrl+C)
      Signal::INT.trap do
        Log.info { "#{Time.utc}: Received SIGINT, shutting down gracefully..." }
        @running = false
      end

      # Handle SIGTERM
      Signal::TERM.trap do
        Log.info { "#{Time.utc}: Received SIGTERM, shutting down gracefully..." }
        @running = false
      end
    end
  end

  # Base Job class
  abstract class Job
    Log = ::Log.for(self)

    getter app : Application
    getter running : Bool = false
    getter interval : Int32
    getter retries : Int32
    getter retry_wait : Int32
    getter timeout : Int32

    def initialize(@app, @interval = 3600, @retries = 3, @retry_wait = 60, @timeout = 300)
    end

    abstract def start
    abstract def stop
    abstract def process

    protected def run_with_retry
      retry_count = 0

      begin
        process
      rescue ex
        retry_count += 1

        if retry_count <= @retries
          Log.warn { "Job failed (attempt #{retry_count}/#{@retries}): #{ex.message}. Retrying in #{@retry_wait} seconds..." }
          sleep(@retry_wait.seconds)
          run_with_retry # Recursively retry
        else
          Log.error { "Job failed after #{@retries} attempts: #{ex.message}" }
          # Could add notification or error handling here
        end
      end
    end
  end

  def self.new
    Application.new
  end
end
