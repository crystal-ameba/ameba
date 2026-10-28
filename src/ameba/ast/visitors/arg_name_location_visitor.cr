module Ameba::AST
  # AST Visitor that sets `Crystal::Arg#name_location` for the arguments
  # whose name doesn't start at the argument location, i.e. the ones with
  # an external name (`foo bar`, `"foo" bar`), or the instance/class variable
  # arguments (`@bar`, `@@bar`).
  class ArgNameLocationVisitor < Crystal::Visitor
    # Creates a new instance of visitor, using *code_lines* of the parsed source.
    def initialize(@code_lines : Array(String))
    end

    # :nodoc:
    def visit(node : Crystal::Arg)
      if (location = node.location) && (column = name_column(node, location))
        node.name_location = location.with(column_number: column)
      end
      true
    end

    # :nodoc:
    def visit(node : Crystal::ASTNode)
      true
    end

    # Returns the column number of the *node* name, or `nil` if it's the same
    # as the *location* column, or the name can't be found within the source
    # (i.e. in case of `__arg0` used in place of `@select`).
    private def name_column(node, location) : Int32?
      return unless line = @code_lines[location.line_number - 1]?

      idx = location.column_number - 1

      # skip the external name, if there's any
      if node.external_name != node.name && line[idx]? != '@'
        return unless idx = skip_external_name(line, idx, node.external_name)

        while line[idx]?.try(&.in?(' ', '\t'))
          idx += 1
        end
      end

      # skip the instance/class variable prefix
      while line[idx]? == '@'
        idx += 1
      end

      return unless line[idx, node.name.size]? == node.name
      return if idx == location.column_number - 1

      idx + 1
    end

    private def skip_external_name(line, idx, name) : Int32?
      unless line[idx]? == '"'
        return unless line[idx, name.size]? == name
        return idx + name.size
      end

      idx += 1
      while char = line[idx]?
        case char
        when '\\' then idx += 2
        when '"'  then return idx + 1
        else           idx += 1
        end
      end
    end
  end
end
