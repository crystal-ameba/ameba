module Ameba::Rule::Style
  # A rule that disallows calls to `is_a?(Nil)` in favor of `nil?`.
  #
  # This is considered bad:
  #
  # ```
  # var.is_a?(Nil)
  # ```
  #
  # And needs to be written as:
  #
  # ```
  # var.nil?
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/IsANil:
  #   Enabled: true
  # ```
  class IsANil < Base
    include AST::Util

    properties do
      since_version "0.13.0"
      description "Disallows calls to `is_a?(Nil)` in favor of `nil?`"
    end

    MSG = "Use `nil?` instead of `is_a?(Nil)`"

    def test(source, node : Crystal::IsA)
      return if node.nil_check?

      const = node.const
      return unless path_named?(const, "Nil")

      if range = nil_check_range(source, node)
        issue_for(const, MSG) do |corrector|
          corrector.replace(range, implicit_self?(node.obj) ? "self.nil?" : "nil?")
        end
      else
        issue_for(const, MSG)
      end
    end

    # Returns the range spanning from the `is_a?` name to the end of the *node*.
    private def nil_check_range(source, node)
      return unless location = node.location
      return unless end_location = node.end_location

      end_pos = source.pos(end_location, end: true)

      # Skip the receiver code, unless it's an implicit one (no end location)
      # or a heredoc (ends past the node)
      if (obj_end_location = node.obj.end_location) && source.pos(obj_end_location) < end_pos
        location = obj_end_location.adjust(column_number: 1)
      end

      lexer = Crystal::Lexer.new(source.code[source.pos(location)...end_pos])
      lexer.line_number = location.line_number
      lexer.column_number = location.column_number

      until (token = lexer.next_token).type.eof?
        if token.keyword?(Crystal::Keyword::IS_A_QUESTION)
          return source.pos(token.location)...end_pos
        end
      end
    rescue Crystal::SyntaxException
    end

    # Receiver-less call, i.e. `is_a?(Nil)`
    private def implicit_self?(obj)
      obj.is_a?(Crystal::Var) && obj.name == "self" && !obj.end_location
    end
  end
end
