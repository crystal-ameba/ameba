module Ameba
  class Source
    record Error,
      rule : String,
      pos : Int32,
      message : String

    getter lines : Array(String)
    getter errors = [] of Error
    getter path : String

    def initialize(@path : String)
      @lines = File.read_lines(@path)
    end

    def error(rule, line_number : Int32, message : String)
      errors << Error.new rule.class.name, line_number, message
    end
  end
end
