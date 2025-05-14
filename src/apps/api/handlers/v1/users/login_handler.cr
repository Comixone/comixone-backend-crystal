require "../../base"
require "../../../../../models/user"

module Comixone::Api::Handlers::V1::Users
  # Handler for user login
  class LoginHandler < Base
    def handle(env)
      handler = "#{self.class.name}#handle"

      begin
        # Parse the request body
        body = env.request.body.try &.gets_to_end

        if body.nil? || body.empty?
          return error(env, "E_INVALID_REQUEST", "Request body is empty", "CLIENT_ERROR", handler)
        end

        # Parse login credentials
        login_data = JSON.parse(body)
        email = login_data["email"]?.try(&.as_s)
        password = login_data["password"]?.try(&.as_s)

        if email.nil? || password.nil?
          return error(env, "E_INVALID_REQUEST", "Email and password are required", "CLIENT_ERROR", handler)
        end

        # Find user by email
        user = find_user_by_email(email)

        if user.nil?
          return error(env, "E_UNAUTHORIZED", "Invalid email or password", "CLIENT_ERROR", handler)
        end

        # Verify password
        if !user.verify_password(password)
          Log.warn { "Failed login attempt for user: #{email}" }
          return error(env, "E_UNAUTHORIZED", "Invalid email or password", "CLIENT_ERROR", handler)
        end

        # Create session or token (JWT would be used here in a real app)
        Log.info { "User logged in successfully: #{email}" }

        # Return user info (excluding password hash)
        success(env, {
          id:    user.id,
          email: user.email,
          name:  user.name,
          roles: user.roles,
        }, handler)
      rescue ex
        Log.error { "Login error: #{ex.message}" }
        error(env, "E_SYSTEM_ERROR", ex.message || "Error during login", "SYSTEM_ERROR", handler)
      end
    end

    private def find_user_by_email(email)
      # Query CouchDB for user with matching email
      result = @app.couchdb.query("_design/users/_view/by_email?key=\"#{email}\"")
      rows = result["rows"].as_a

      if rows.size > 0
        # Get the first matching user
        user_doc = rows[0]["value"]
        return Comixone::Models::User.from_json_object(user_doc)
      end

      nil
    end
  end
end
