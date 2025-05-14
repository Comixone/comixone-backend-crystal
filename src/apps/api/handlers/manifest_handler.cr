require "./base"

module Comixone::Api::Handlers
  class ManifestHandler < Base
    def handle(env)
      handler = "#{self.class.name}#handle"

      begin
        manifest = {
          name:         @app.name,
          version:      Comixone::Api::VERSION,
          dependencies: {
            couchdb: {
              version: Comixone::Lib::CouchDB::VERSION,
              status:  @app.couchdb.healthy? ? "connected" : "disconnected",
            },
            dragonfly: {
              version: Comixone::Lib::Dragonfly::VERSION,
              status:  @app.dragonfly.healthy? ? "connected" : "disconnected",
            },
          },
        }

        success(env, manifest, handler)
      rescue ex
        error(env, "E_SYSTEM_ERROR", ex.message || "Failed to get manifest", "SYSTEM_ERROR", handler)
      end
    end
  end
end
