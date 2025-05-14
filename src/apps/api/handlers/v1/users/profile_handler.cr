require "../../base"
require "../../../../../models/user"

module Comixone::Api::Handlers::V1::Users
  # Handler for getting current user profile
  class ProfileHandler < Base
    def handle(env)
      handler = "#{self.class.name}#handle"

      begin
        # Get the current user from the context (set by auth middleware)
        user = env.get?("current_user").try(&.as(Comixone::Models::User))

        if user.nil?
          return error(env, "E_UNAUTHORIZED", "Not authenticated", "CLIENT_ERROR", handler)
        end

        # Return user profile
        success(env, {
          id:         user.id,
          email:      user.email,
          name:       user.name,
          roles:      user.roles,
          created_at: user.created_at,
          updated_at: user.updated_at,
        }, handler)
      rescue ex
        error(env, "E_SYSTEM_ERROR", ex.message || "Error getting profile", "SYSTEM_ERROR", handler)
      end
    end
  end
end
