require "base64"
require "log"
require "../../../models/user"

module Comixone::Api::Middlewares
  # Authentication middleware that uses the database for user validation
  class DatabaseAuth < Kemal::Handler
    Log = ::Log.for(self)

    def initialize(@app : Comixone::Api::Application)
    end

    def call(env)
      return call_next(env) unless needs_auth?(env)

      if authorized?(env)
        # Store the authenticated user in the context for handlers to use
        env.set("current_user", env.get("auth_user"))
        call_next(env)
      else
        env.response.status_code = 401
        env.response.headers["WWW-Authenticate"] = "Basic realm=\"Comixone API\""
        env.response.content_type = "application/json"

        {
          error:   {code: "E_UNAUTHORIZED", message: "Unauthorized"},
          status:  "CLIENT_ERROR",
          body:    nil,
          route:   env.request.path,
          handler: "",
        }.to_json
      end
    end

    private def needs_auth?(env)
      # Skip authentication for these public endpoints
      !["/healthz", "/manifest", "/"].includes?(env.request.path)
    end

    private def authorized?(env)
      auth_header = env.request.headers["Authorization"]?
      return false unless auth_header

      if auth_header.starts_with?("Basic ")
        credentials = auth_header[6..]

        begin
          decoded = String.new(Base64.decode(credentials))
          email, password = decoded.split(":", 2)

          # Look up user by email
          user = find_user_by_email(email)
          return false unless user

          # Verify password
          if user.verify_password(password)
            # Store user in context for later use
            env.set("auth_user", user)
            return true
          end
        rescue ex
          Log.error { "Error during authentication: #{ex.message}" }
        end
      end

      false
    end

    private def find_user_by_email(email)
      begin
        # Query CouchDB for user with matching email
        result = @app.couchdb.query("_design/users/_view/by_email?key=\"#{email}\"")
        rows = result["rows"].as_a

        if rows.size > 0
          # Get the first matching user
          user_doc = rows[0]["value"]
          return Comixone::Models::User.from_json_object(user_doc)
        end
      rescue ex
        Log.error { "Error finding user: #{ex.message}" }
      end

      nil
    end
  end

  # JWT Authentication handler for token-based authentication
  class JwtAuth < Kemal::Handler
    Log = ::Log.for(self)

    def initialize(@app : Comixone::Api::Application)
    end

    def call(env)
      return call_next(env) unless needs_auth?(env)

      if authorized?(env)
        call_next(env)
      else
        env.response.status_code = 401
        env.response.content_type = "application/json"

        {
          error:   {code: "E_UNAUTHORIZED", message: "Invalid or expired token"},
          status:  "CLIENT_ERROR",
          body:    nil,
          route:   env.request.path,
          handler: "",
        }.to_json
      end
    end

    private def needs_auth?(env)
      # JWT auth only applies to routes that explicitly need it
      # This is a placeholder - implement based on your needs
      false
    end

    private def authorized?(env)
      # This is a placeholder for JWT verification
      # Will be implemented when JWT auth is needed
      false
    end
  end
end
