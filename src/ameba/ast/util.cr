# Utility module for Ameba's rules.
module Ameba::AST::Util
  # Returns true if current `node` is a literal, false - otherwise.
  def literal?(node)
    node.try &.class.name.ends_with? "Literal"
  end

  # Returns true if current `node` is a string literal, false - otherwise.
  def string_literal?(node)
    node.is_a? Crystal::StringLiteral
  end

  # Returns a source code for the current node.
  # This method uses `node.location` and `node.end_location`
  # to determine and cut a piece of source of the node.
  def node_source(node, code_lines)
    loc, end_loc = node.location, node.end_location

    return unless loc && end_loc

    line, column = loc.line_number - 1, loc.column_number - 1
    end_line, end_column = end_loc.line_number - 1, end_loc.column_number - 1
    node_lines = code_lines[line..end_line]
    first_line, last_line = node_lines[0]?, node_lines[-1]?

    return unless first_line && last_line

    node_lines[0] = first_line.sub(0...column, "")

    if line == end_line # one line
      end_column = end_column - column
      last_line = node_lines[0]
    end
    node_lines[-1] = last_line.sub(end_column + 1...last_line.size, "")

    node_lines
  end
end
