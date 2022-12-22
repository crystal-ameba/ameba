require "./rewriter"

class Ameba::Source
  # This class takes source code and rewrites it based
  # on the different correction actions supplied.
  class Corrector
    @line_sizes = [] of Int32

    def initialize(code : String)
      code.each_line(chomp: false) do |line|
        @line_sizes << line.size
      end
      @rewriter = Rewriter.new(code)
    end

    # Replaces the code of the given range with *content*.
    def replace(location, end_location, content)
      @rewriter.replace(loc_to_pos(location), loc_to_pos(end_location) + 1, content)
    end

    # :ditto:
    def replace(range : Range(Int32, Int32), content)
      begin_pos, end_pos = range.begin, range.end
      end_pos -= 1 unless range.excludes_end?
      @rewriter.replace(begin_pos, end_pos, content)
    end

    # Inserts the given strings before and after the given range.
    def wrap(location, end_location, insert_before, insert_after)
      @rewriter.wrap(loc_to_pos(location), loc_to_pos(end_location) + 1, insert_before, insert_after)
    end

    # :ditto:
    def wrap(range : Range(Int32, Int32), insert_before, insert_after)
      begin_pos, end_pos = range.begin, range.end
      end_pos -= 1 unless range.excludes_end?
      @rewriter.wrap(begin_pos, end_pos, insert_before, insert_after)
    end

    # Shortcut for `replace(location, end_location, "")`
    def remove(location, end_location)
      @rewriter.remove(loc_to_pos(location), loc_to_pos(end_location) + 1)
    end

    # Shortcut for `replace(range, "")`
    def remove(range : Range(Int32, Int32))
      begin_pos, end_pos = range.begin, range.end
      end_pos -= 1 unless range.excludes_end?
      @rewriter.remove(begin_pos, end_pos)
    end

    # Shortcut for `wrap(location, end_location, content, nil)`
    def insert_before(location, end_location, content)
      @rewriter.insert_before(loc_to_pos(location), loc_to_pos(end_location) + 1, content)
    end

    # Shortcut for `wrap(range, content, nil)`
    def insert_before(range : Range(Int32, Int32), content)
      begin_pos, end_pos = range.begin, range.end
      end_pos -= 1 unless range.excludes_end?
      @rewriter.insert_before(begin_pos, end_pos, content)
    end

    # Shortcut for `wrap(location, end_location, nil, content)`
    def insert_after(location, end_location, content)
      @rewriter.insert_after(loc_to_pos(location), loc_to_pos(end_location) + 1, content)
    end

    # Shortcut for `wrap(range, nil, content)`
    def insert_after(range : Range(Int32, Int32), content)
      begin_pos, end_pos = range.begin, range.end
      end_pos -= 1 unless range.excludes_end?
      @rewriter.insert_after(begin_pos, end_pos, content)
    end

    # Shortcut for `insert_before(location, location, content)`
    def insert_before(location, content)
      @rewriter.insert_before(loc_to_pos(location), content)
    end

    # Shortcut for `insert_before(pos.., content)`
    def insert_before(pos : Int32, content)
      @rewriter.insert_before(pos, content)
    end

    # Shortcut for `insert_after(location, location, content)`
    def insert_after(location, content)
      @rewriter.insert_after(loc_to_pos(location) + 1, content)
    end

    # Shortcut for `insert_after(...pos, content)`
    def insert_after(pos : Int32, content)
      @rewriter.insert_after(pos, content)
    end

    # Removes *size* characters prior to the source range.
    def remove_preceding(location, end_location, size)
      @rewriter.remove(loc_to_pos(location) - size, loc_to_pos(location))
    end

    # :ditto:
    def remove_preceding(range : Range(Int32, Int32), size)
      begin_pos = range.begin
      @rewriter.remove(begin_pos - size, begin_pos)
    end

    # Removes *size* characters from the beginning of the given range.
    # If *size* is greater than the size of the range, the removed region can
    # overrun the end of the range.
    def remove_leading(location, end_location, size)
      @rewriter.remove(loc_to_pos(location), loc_to_pos(location) + size)
    end

    # :ditto:
    def remove_leading(range : Range(Int32, Int32), size)
      begin_pos = range.begin
      @rewriter.remove(begin_pos, begin_pos + size)
    end

    # Removes *size* characters from the end of the given range.
    # If *size* is greater than the size of the range, the removed region can
    # overrun the beginning of the range.
    def remove_trailing(location, end_location, size)
      @rewriter.remove(loc_to_pos(end_location) + 1 - size, loc_to_pos(end_location) + 1)
    end

    # :ditto:
    def remove_trailing(range : Range(Int32, Int32), size)
      end_pos = range.end
      end_pos -= 1 unless range.excludes_end?
      @rewriter.remove(end_pos - size, end_pos)
    end

    private def loc_to_pos(location : Crystal::Location | {Int32, Int32})
      if location.is_a?(Crystal::Location)
        line, column = location.line_number, location.column_number
      else
        line, column = location
      end
      @line_sizes[0...line - 1].sum + (column - 1)
    end

    # Replaces the code of the given node with *content*.
    def replace(node : Crystal::ASTNode, content)
      replace(location(node), end_location(node), content)
    end

    # Inserts the given strings before and after the given node.
    def wrap(node : Crystal::ASTNode, insert_before, insert_after)
      wrap(location(node), end_location(node), insert_before, insert_after)
    end

    # Shortcut for `replace(node, "")`
    def remove(node : Crystal::ASTNode)
      remove(location(node), end_location(node))
    end

    # Shortcut for `wrap(node, content, nil)`
    def insert_before(node : Crystal::ASTNode, content)
      insert_before(location(node), content)
    end

    # Shortcut for `wrap(node, nil, content)`
    def insert_after(node : Crystal::ASTNode, content)
      insert_after(end_location(node), content)
    end

    # Removes *size* characters prior to the given node.
    def remove_preceding(node : Crystal::ASTNode, size)
      remove_preceding(location(node), end_location(node), size)
    end

    # Removes *size* characters from the beginning of the given node.
    # If *size* is greater than the size of the node, the removed region can
    # overrun the end of the node.
    def remove_leading(node : Crystal::ASTNode, size)
      remove_leading(location(node), end_location(node), size)
    end

    # Removes *size* characters from the end of the given node.
    # If *size* is greater than the size of the node, the removed region can
    # overrun the beginning of the node.
    def remove_trailing(node : Crystal::ASTNode, size)
      remove_trailing(location(node), end_location(node), size)
    end

    private def location(node : Crystal::ASTNode)
      node.location || raise "Missing location"
    end

    private def end_location(node : Crystal::ASTNode)
      node.end_location || raise "Missing end location"
    end

    # Applies all scheduled changes and returns modified source as a new string.
    def process
      @rewriter.process
    end
  end
end
