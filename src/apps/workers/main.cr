require "./comixone-workers"
require "../../config"
require "../../lib/couchdb"
require "../../lib/dragonfly"
require "../../models/index"
require "./jobs/*"

app = Comixone::Workers.new
app.init
app.run
