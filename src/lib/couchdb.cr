require "http/client"
require "json"
require "uri"
require "log"

module Comixone::Lib
  class CouchDB
    VERSION = "0.1.0"

    # Create a logger for this class
    Log = ::Log.for(self)

    # Error classes
    class Error < Exception; end

    class ConnectionError < Error; end

    class DocumentNotFoundError < Error; end

    class DatabaseError < Error; end

    # Properties
    getter url : String
    getter username : String
    getter password : String
    getter database : String
    getter connected : Bool = false
    getter config : Comixone::Config::CouchDBConfig

    # Initialize with configuration
    def initialize(config : Comixone::Config::CouchDBConfig)
      @config = config
      @url = config.url
      @username = config.username
      @password = config.password
      @database = config.database

      connect
    end

    # Connect to CouchDB
    def connect
      begin
        Log.info { "Connecting to CouchDB at #{@url}" }
        client = authorized_client
        response = run_with_retry { client.get("#{@url}/_up") }
        @connected = response.status_code == 200

        if @connected && @config.create_if_missing
          ensure_database_exists
        end

        Log.info { "Connected to CouchDB successfully" }
      rescue ex
        @connected = false
        Log.error { "Failed to connect to CouchDB: #{ex.message}" }
        raise ConnectionError.new("Failed to connect to CouchDB: #{ex.message}")
      end
    end

    # Check if CouchDB is healthy
    def healthy?
      begin
        client = HTTP::Client.new(URI.parse(@url))
        client.connect_timeout = 5.seconds
        response = client.get("/_up")
        response.status_code == 200
      rescue ex
        Log.warn { "CouchDB health check failed: #{ex.message}" }
        false
      end
    end

    # Create database if it doesn't exist
    def ensure_database_exists
      begin
        Log.debug { "Checking if database '#{@database}' exists" }
        client = authorized_client
        response = run_with_retry { client.head("#{@url}/#{@database}") }

        if response.status_code == 404
          Log.info { "Database '#{@database}' not found, creating..." }
          create_response = run_with_retry { client.put("#{@url}/#{@database}", body: "") }

          if create_response.status_code != 201
            raise DatabaseError.new("Failed to create database: #{create_response.body}")
          end

          Log.info { "Database '#{@database}' created successfully" }
        else
          Log.debug { "Database '#{@database}' already exists" }
        end
      rescue ex : DatabaseError
        raise ex
      rescue ex
        Log.error { "Failed to ensure database exists: #{ex.message}" }
        raise DatabaseError.new("Failed to ensure database exists: #{ex.message}")
      end
    end

    # Create a document
    def create_document(doc)
      Log.debug { "Creating document" }
      client = authorized_client

      body = case doc
             when String
               doc
             else
               doc.to_json
             end

      response = run_with_retry do
        client.post(
          "#{@url}/#{@database}",
          headers: HTTP::Headers{"Content-Type" => "application/json"},
          body: body
        )
      end

      if response.status_code != 201
        msg = "Failed to create document: #{response.body}"
        Log.error { msg }
        raise Error.new(msg)
      end

      result = JSON.parse(response.body)
      Log.debug { "Document created successfully with id: #{result["id"]?}" }

      result
    end

    # Get a document by ID
    def get_document(id)
      Log.debug { "Getting document with id: #{id}" }
      client = authorized_client

      response = run_with_retry { client.get("#{@url}/#{@database}/#{id}") }

      if response.status_code == 404
        msg = "Document not found: #{id}"
        Log.debug { msg }
        raise DocumentNotFoundError.new(msg)
      elsif response.status_code != 200
        msg = "Failed to get document: #{response.body}"
        Log.error { msg }
        raise Error.new(msg)
      end

      result = JSON.parse(response.body)
      Log.debug { "Document retrieved successfully" }

      result
    end

    # Update a document
    def update_document(id, doc)
      Log.debug { "Updating document with id: #{id}" }
      begin
        existing = get_document(id)
        rev = existing["_rev"].as_s

        # Create a new hash with the content and add _id and _rev
        doc_hash = case doc
                   when Hash
                     doc
                   when String
                     JSON.parse(doc).as_h
                   else
                     begin
                       JSON.parse(doc.to_json).as_h
                     rescue
                       raise Error.new("Could not convert document to JSON")
                     end
                   end

        # Make sure we're working with a hash we can modify
        doc_hash = doc_hash.dup if doc_hash.is_a?(Hash)

        # Add required fields
        doc_hash["_id"] = id
        doc_hash["_rev"] = rev

        client = authorized_client
        response = run_with_retry do
          client.put(
            "#{@url}/#{@database}/#{id}",
            headers: HTTP::Headers{"Content-Type" => "application/json"},
            body: doc_hash.to_json
          )
        end

        if response.status_code != 201
          msg = "Failed to update document: #{response.body}"
          Log.error { msg }
          raise Error.new(msg)
        end

        result = JSON.parse(response.body)
        Log.debug { "Document updated successfully" }

        result
      rescue ex : DocumentNotFoundError
        Log.debug { "Document not found during update: #{id}" }
        raise ex
      rescue ex
        Log.error { "Failed to update document: #{ex.message}" }
        raise Error.new("Failed to update document: #{ex.message}")
      end
    end

    # Delete a document
    def delete_document(id)
      Log.debug { "Deleting document with id: #{id}" }
      begin
        existing = get_document(id)
        rev = existing["_rev"].as_s

        client = authorized_client
        response = run_with_retry { client.delete("#{@url}/#{@database}/#{id}?rev=#{rev}") }

        if response.status_code != 200
          msg = "Failed to delete document: #{response.body}"
          Log.error { msg }
          raise Error.new(msg)
        end

        result = JSON.parse(response.body)
        Log.debug { "Document deleted successfully" }

        result
      rescue ex : DocumentNotFoundError
        Log.debug { "Document not found during delete: #{id}" }
        raise ex
      rescue ex
        Log.error { "Failed to delete document: #{ex.message}" }
        raise Error.new("Failed to delete document: #{ex.message}")
      end
    end

    # Query a view
    def query(view_path, options = {} of String => String)
      Log.debug { "Querying view: #{view_path} with options: #{options}" }
      client = authorized_client

      query_string = options.map { |k, v| "#{k}=#{URI.encode_www_form(v)}" }.join("&")
      path = "#{@url}/#{@database}/#{view_path}"
      path += "?#{query_string}" unless query_string.empty?

      response = run_with_retry { client.get(path) }

      if response.status_code != 200
        msg = "Failed to query view: #{response.body}"
        Log.error { msg }
        raise Error.new(msg)
      end

      result = JSON.parse(response.body)
      Log.debug { "View query successful, returned #{result["rows"]?.try(&.as_a.size) || 0} rows" }

      result
    end

    # Bulk operations
    def bulk_docs(docs)
      Log.debug { "Performing bulk operation with #{docs.size} documents" }
      client = authorized_client

      bulk_data = {"docs" => docs}

      response = run_with_retry do
        client.post(
          "#{@url}/#{@database}/_bulk_docs",
          headers: HTTP::Headers{"Content-Type" => "application/json"},
          body: bulk_data.to_json
        )
      end

      if response.status_code != 201
        msg = "Failed to perform bulk operation: #{response.body}"
        Log.error { msg }
        raise Error.new(msg)
      end

      result = JSON.parse(response.body).as_a
      Log.debug { "Bulk operation completed successfully" }

      result
    end

    # Mango query
    def find(selector, options = {} of String => JSON::Any)
      Log.debug { "Performing find operation with selector: #{selector}" }
      client = authorized_client

      query = {"selector" => selector}.merge(options)

      response = run_with_retry do
        client.post(
          "#{@url}/#{@database}/_find",
          headers: HTTP::Headers{"Content-Type" => "application/json"},
          body: query.to_json
        )
      end

      if response.status_code != 200
        msg = "Failed to perform find operation: #{response.body}"
        Log.error { msg }
        raise Error.new(msg)
      end

      result = JSON.parse(response.body)
      Log.debug { "Find operation completed successfully, returned #{result["docs"]?.try(&.as_a.size) || 0} documents" }

      result
    end

    # Create an HTTP client with basic auth
    private def authorized_client
      uri = URI.parse(@url)
      client = HTTP::Client.new(uri)
      client.basic_auth(@username, @password)
      client.connect_timeout = @config.connect_timeout.seconds
      client.read_timeout = @config.request_timeout.seconds
      client
    end

    # Retry a block with configurable retries
    private def run_with_retry(&)
      attempts = 0
      max_attempts = @config.retry_count + 1 # +1 because first attempt doesn't count as a retry

      loop do
        attempts += 1

        begin
          return yield # Return the result if successful
        rescue ex : IO::TimeoutError | IO::Error | Socket::Error
          if attempts < max_attempts
            # Log the error and retry
            retry_wait = @config.retry_wait.seconds
            Log.warn { "Request failed (attempt #{attempts}/#{max_attempts}): #{ex.message}. Retrying in #{retry_wait.total_seconds} seconds..." }
            sleep(retry_wait)
          else
            # Max retries reached, re-raise the exception
            Log.error { "Request failed after #{attempts} attempts: #{ex.message}" }
            raise ex
          end
        end
      end
    end
  end
end
