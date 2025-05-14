require "kemal"

module Comixone::Api
  VERSION = "0.1.0"

  def init
    get "/" do
      "Hello World!"
    end
  end

  def run
    Kemal.run
  end
end
