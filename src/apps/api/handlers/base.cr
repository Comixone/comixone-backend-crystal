require "log"

module Comixone::Api::Handlers
  # Base handler class for all API handlers
  abstract class Base
    Log = ::Log.for(self)

    getter app : Comixone::Api::Application

    def initialize(@app)
    end

    # All handlers must implement handle
    abstract def handle(env)

    # Format a successful response
    def success(env, body, handler = "")
      Log.debug { "Generating success response for #{env.request.method} #{env.request.path}" }
      format_response(env, body: body, handler: handler)
    end

    # Format an error response
    def error(env, code, message, status = "CLIENT_ERROR", handler = "")
      Log.debug { "Generating error response (#{code}: #{message}) for #{env.request.method} #{env.request.path}" }
      format_response(
        env,
        error: {code: code, message: message},
        status: status,
        handler: handler
      )
    end

    # Format the standard response
    private def format_response(env, error = nil, status = "OK", body = nil, handler = "")
      is_debug = env.params.query["debug"]? == "true"

      response = {
        error:   error,
        status:  status,
        body:    body,
        route:   env.request.path,
        handler: handler,
      }

      if is_debug
        Log.debug { "Debug mode enabled for request, including additional debug information" }
        request = env.request
        headers = [] of Hash(String, String)

        request.headers.each do |key, values|
          values.each do |value|
            # Skip sensitive headers in logs
            unless ["Authorization", "Cookie", "Set-Cookie"].includes?(key)
              headers << {"key" => key, "value" => value}
            end
          end
        end

        query_params = [] of Hash(String, String)
        request.query_params.each do |key, value|
          query_params << {"key" => key, "value" => value}
        end

        body_content = request.body.try &.gets_to_end
        body_display = nil

        if body_content
          begin
            # Try to parse as JSON for nicer display
            parsed = JSON.parse(body_content)

            # Redact any sensitive fields
            if parsed_hash = parsed.as_h?
              sensitive_fields = ["password", "token", "secret", "key", "apiKey", "api_key"]

              # Create a new hash to store the modified values
              redacted_hash = Hash(String, JSON::Any).new

              # Copy all values, redacting sensitive ones
              parsed_hash.each do |key, value|
                if sensitive_fields.includes?(key)
                  redacted_hash[key] = JSON::Any.new("REDACTED")
                else
                  redacted_hash[key] = value
                end
              end

              # Replace parsed with the redacted version
              parsed = JSON::Any.new(redacted_hash)
            end

            body_display = parsed
          rescue
            # If not JSON, just use the raw content
            body_display = body_content
          end
        end

        response = response.merge({
          debug: {
            request: {
              ip:      request.remote_address,
              method:  request.method,
              headers: headers,
              url:     {
                proto: request.headers["X-Forwarded-Proto"]? || "http",
                host:  request.headers["Host"]?,
                port:  request.headers["Host"]?.try {
                 |host| host.includes?(":")
                 ? host.split(":")[1].to_i
                 : (request.headers["X-Forwarded-Proto"]? == "https" ? 443 : 80)
                },
                uri:   request.path,
              },
              query: query_params,
              body:  body_display,
            },
            info: {
              timestamp:   Time.utc.to_s,
              server:      @app.name,
              version:     Comixone::Api::VERSION,
              environment: @app.config.server.environment,
            },
          },
        })
      end

      env.response.content_type = "application/json"
      response.to_json
    end
  end
end
