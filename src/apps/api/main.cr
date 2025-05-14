require "./comixone-api"
require "../../config"
require "../../lib/couchdb"
require "../../lib/dragonfly"
require "../../models/index"
require "./handlers/**"
require "./routing/**"

app = Comixone::Api.new
app.init
app.run
