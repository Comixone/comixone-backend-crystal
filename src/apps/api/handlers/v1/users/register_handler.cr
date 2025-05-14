require "../../base"
require "../../../../../models/user"

module Comixone::Api::Handlers::V1::Users
  # Handler for user registration
  class RegisterHandler < Base
    def handle(env)
      handler = "#{self.class.name}#handle"

      begin
        # Parse the request body
        body = env.request.body.try &.gets_to_end

        if body.nil? || body.empty?
          return error(env, "E_INVALID_REQUEST", "Request body is empty", "CLIENT_ERROR", handler)
        end

        # Parse registration data
        reg_data = JSON.parse(body)
        email = reg_data["email"]?.try(&.as_s)
        name = reg_data["name"]?.try(&.as_s)
        password = reg_data["password"]?.try(&.as_s)

        if email.nil? || name.nil? || password.nil?
          return error(env, "E_INVALID_REQUEST", "Email, name, and password are required", "CLIENT_ERROR", handler)
        end

        # Validate email format
        unless email.includes?("@")
          return error(env, "E_INVALID_REQUEST", "Invalid email format", "CLIENT_ERROR", handler)
        end

        # Validate password strength
        if password.size < 8
          return error(env, "E_INVALID_REQUEST", "Password must be at least 8 characters", "CLIENT_ERROR", handler)
        end

        # Check if user already exists
        if user_exists?(email)
          return error(env, "E_CONFLICT", "A user with this email already exists", "CLIENT_ERROR", handler)
        end

        # Create new user
        user = Comixone::Models::User.new(
          email: email,
          name: name,
          password: password
        )

        # Save to database
        user_id = Random.new.hex(8)
        user.id = user_id

        @app.couchdb.create_document(user.to_db_hash)

        Log.info { "New user registered: #{email}" }

        # Return success with user info (excluding password hash)
        success(env, {
          id:    user.id,
          email: user.email,
          name:  user.name,
          roles: user.roles,
        }, handler)
      rescue ex
        Log.error { "Registration error: #{ex.message}" }
        error(env, "E_SYSTEM_ERROR", ex.message || "Error during registration", "SYSTEM_ERROR", handler)
      end
    end

    private def user_exists?(email)
      # Query CouchDB for user with matching email
      result = @app.couchdb.query("_design/users/_view/by_email?key=\"#{email}\"")
      rows = result["rows"].as_a

      rows.size > 0
    end
  end
end
