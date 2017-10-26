module Ameba
  class Source
    getter lines : Array(String)
    getter errors = [] of String

    def initialize(content : String)
      @lines = content.split "\n"
    end
  end
end
