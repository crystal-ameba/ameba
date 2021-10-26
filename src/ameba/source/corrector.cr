require "./rewriter"

class Ameba::Source
  class Corrector
    @line_sizes : Array(Int32)

    def initialize(code : String)
      @rewriter = Rewriter.new(code)
      @line_sizes = code.lines(chomp: false).map(&.size)
    end

    alias SourceLocation = Crystal::Location | {Int32, Int32}

    def replace(location : SourceLocation, end_location : SourceLocation, content)
      @rewriter.replace(loc_to_pos(location), loc_to_pos(end_location) + 1, content)
    end

    def wrap(location : SourceLocation, end_location : SourceLocation, insert_before, insert_after)
      @rewriter.wrap(loc_to_pos(location), loc_to_pos(end_location) + 1, insert_before, insert_after)
    end

    def remove(location : SourceLocation, end_location : SourceLocation)
      @rewriter.remove(loc_to_pos(location), loc_to_pos(end_location) + 1)
    end

    def insert_before(location : SourceLocation, content)
      @rewriter.insert_before(loc_to_pos(location), content)
    end

    def insert_after(location : SourceLocation, content)
      @rewriter.insert_after(loc_to_pos(location) + 1, content)
    end

    private def loc_to_pos(location : SourceLocation)
      if location.is_a?(Crystal::Location)
        line, column = location.line_number, location.column_number
      else
        line, column = location
      end
      @line_sizes[0...line - 1].sum + (column - 1)
    end

    def replace(node : Crystal::ASTNode, content)
      replace(location(node), end_location(node), content)
    end

    def wrap(node : Crystal::ASTNode, insert_before, insert_after)
      wrap(location(node), end_location(node), insert_before, insert_after)
    end

    def remove(node : Crystal::ASTNode)
      remove(location(node), end_location(node))
    end

    def insert_before(node : Crystal::ASTNode, content)
      insert_before(location(node), content)
    end

    def insert_after(node : Crystal::ASTNode, content)
      insert_after(end_location(node), content)
    end

    private def location(node : Crystal::ASTNode)
      node.location || raise "Missing location"
    end

    private def end_location(node : Crystal::ASTNode)
      node.end_location || raise "Missing end location"
    end

    def process
      @rewriter.process
    end
  end
end
