require "redis"
require "log"

module Comixone::Lib
  class Dragonfly
    VERSION = "0.1.0"
    Log     = ::Log.for(self)

    class Error < Exception
    end

    class ConnectionError < Error
    end

    property url : String
    property password : String?
    property database : Int32
    property connected : Bool = false
    property client : Redis::PooledClient?
    property config : Comixone::Config::DragonflyConfig

    def initialize(config : Comixone::Config::DragonflyConfig)
      @config = config
      @url = config.url
      @password = config.password
      @database = config.database

      connect
    end

    def connect
      begin
        Log.info { "Connecting to Dragonfly at #{@url}" }
        uri = URI.parse(@url)
        @client = Redis::PooledClient.new(
          host: uri.host || "localhost",
          port: uri.port || 6379,
          password: @password,
          database: @database,
        )

        # Test connection
        ping_result = run_with_retry { @client.not_nil!.ping }
        @connected = ping_result == "PONG"

        Log.info { "Connected to Dragonfly successfully" }
      rescue ex
        @connected = false
        @client = nil
        Log.error { "Failed to connect to Dragonfly/Redis: #{ex.message}" }
        raise ConnectionError.new("Failed to connect to Dragonfly/Redis: #{ex.message}")
      end
    end

    def healthy?
      begin
        @client.try &.ping == "PONG"
      rescue ex
        Log.warn { "Dragonfly health check failed: #{ex.message}" }
        false
      end
    end

    def get(key)
      Log.debug { "Getting key: #{key}" }
      validate_connection
      run_with_retry { @client.not_nil!.get(key) }
    end

    def set(key, value, ex = nil)
      validate_connection

      Log.debug { "Setting key: #{key} #{ex ? "with expiry: #{ex}" : ""}" }
      if ex
        run_with_retry { @client.not_nil!.set(key, value, ex: ex) }
      else
        run_with_retry { @client.not_nil!.set(key, value) }
      end
    end

    def delete(key)
      Log.debug { "Deleting key: #{key}" }
      validate_connection
      run_with_retry { @client.not_nil!.del(key) }
    end

    def exists?(key)
      Log.debug { "Checking if key exists: #{key}" }
      validate_connection
      run_with_retry { @client.not_nil!.exists(key) > 0 }
    end

    def expire(key, seconds)
      Log.debug { "Setting expiry for key: #{key} to #{seconds} seconds" }
      validate_connection
      run_with_retry { @client.not_nil!.expire(key, seconds) }
    end

    def publish(channel, message)
      Log.debug { "Publishing message to channel: #{channel}" }
      validate_connection
      run_with_retry { @client.not_nil!.publish(channel, message) }
    end

    def subscribe(channel, &block : String, String -> Nil)
      Log.debug { "Subscribing to channel: #{channel}" }
      validate_connection
      subscription = @client.not_nil!.subscribe(channel)

      loop do
        subscription.next_message do |msg|
          Log.debug { "Received message from channel: #{msg.channel}" }
          block.call(msg.channel, msg.payload)
        end
      end
    end

    def hash_set(key, field, value)
      Log.debug { "Setting hash field: #{key}[#{field}]" }
      validate_connection
      run_with_retry { @client.not_nil!.hset(key, field, value) }
    end

    def hash_get(key, field)
      Log.debug { "Getting hash field: #{key}[#{field}]" }
      validate_connection
      run_with_retry { @client.not_nil!.hget(key, field) }
    end

    def hash_get_all(key)
      Log.debug { "Getting all hash fields for key: #{key}" }
      validate_connection
      run_with_retry { @client.not_nil!.hgetall(key) }
    end

    def increment(key, by = 1)
      Log.debug { "Incrementing key: #{key} by #{by}" }
      validate_connection
      run_with_retry { @client.not_nil!.incrby(key, by) }
    end

    def decrement(key, by = 1)
      Log.debug { "Decrementing key: #{key} by #{by}" }
      validate_connection
      run_with_retry { @client.not_nil!.decrby(key, by) }
    end

    def set_add(key, member)
      Log.debug { "Adding member to set: #{key}" }
      validate_connection
      run_with_retry { @client.not_nil!.sadd(key, member) }
    end

    def set_members(key)
      Log.debug { "Getting set members: #{key}" }
      validate_connection
      run_with_retry { @client.not_nil!.smembers(key) }
    end

    def set_remove(key, member)
      Log.debug { "Removing member from set: #{key}" }
      validate_connection
      run_with_retry { @client.not_nil!.srem(key, member) }
    end

    def list_push(key, value)
      Log.debug { "Pushing value to list: #{key}" }
      validate_connection
      run_with_retry { @client.not_nil!.rpush(key, value) }
    end

    def list_pop(key)
      Log.debug { "Popping value from list: #{key}" }
      validate_connection
      run_with_retry { @client.not_nil!.lpop(key) }
    end

    def flush_all
      Log.warn { "Flushing all keys" }
      validate_connection
      run_with_retry { @client.not_nil!.flushall }
    end

    private def validate_connection
      unless @connected && @client
        Log.info { "Connection not active, reconnecting..." }
        connect

        unless @connected && @client
          raise ConnectionError.new("Not connected to Dragonfly/Redis")
        end
      end
    end

    # Retry a block with configurable retries
    private def run_with_retry(&)
      attempts = 0
      max_attempts = @config.max_retries + 1 # +1 because first attempt doesn't count as a retry

      loop do
        attempts += 1

        begin
          return yield # Return the result if successful
        rescue ex : IO::TimeoutError | IO::Error | Socket::Error | Redis::Error
          if attempts < max_attempts
            # Log the error and retry
            retry_interval = @config.retry_interval.seconds
            Log.warn { "Redis command failed (attempt #{attempts}/#{max_attempts}): #{ex.message}. Retrying in #{retry_interval.total_seconds} seconds..." }
            sleep(retry_interval)
          else
            # Max retries reached, re-raise the exception
            Log.error { "Redis command failed after #{attempts} attempts: #{ex.message}" }
            raise ex
          end
        end
      end
    end
  end
end
