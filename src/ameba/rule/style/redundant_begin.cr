module Ameba::Rule::Style
  # A rule that disallows redundant `begin` blocks.
  #
  # Currently it is able to detect:
  #
  # 1. Exception handler block that can be used as a part of the method.
  #
  # For example, this:
  #
  # ```
  # def method
  #   begin
  #     read_content
  #   rescue
  #     close_file
  #   end
  # end
  # ```
  #
  # should be rewritten as:
  #
  # ```
  # def method
  #   read_content
  # rescue
  #   close_file
  # end
  # ```
  #
  # 2. `begin`..`end` block as a top level block in a method.
  #
  # For example this is considered invalid:
  #
  # ```
  # def method
  #   begin
  #     a = 1
  #     b = 2
  #   end
  # end
  # ```
  #
  # and has to be written as the following:
  #
  # ```
  # def method
  #   a = 1
  #   b = 2
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Style/RedundantBegin:
  #   Enabled: true
  # ```
  class RedundantBegin < Base
    include AST::Util

    properties do
      since_version "0.3.0"
      description "Disallows redundant `begin` blocks"
    end

    MSG = "Redundant `begin` block detected"

    def test(source, node : Crystal::Def | Crystal::Block)
      return unless begin_node = redundant_begin_node(node.body)

      return unless begin_loc = begin_node.location
      return unless end_end_loc = begin_node.end_location

      return unless starts_line?(source, begin_loc)
      return unless exception_handler_allowed?(source, node)

      begin_end_loc = begin_loc.adjust(column_number: {{ "begin".size - 1 }})
      end_loc = end_end_loc.adjust(column_number: -{{ "end".size - 1 }})

      issue_for(begin_loc, begin_end_loc, MSG) do |corrector|
        corrector.remove(begin_loc, begin_end_loc)
        corrector.remove(end_loc, end_end_loc)
      end
    end

    private def redundant_begin_node(body)
      case body
      when Crystal::ExceptionHandler
        return if begin_exprs_in_handler?(body) || inner_handler?(body)
        return if body.suffix
        return body unless body.implicit

        first_begin_expression(body.body)
      when Crystal::Expressions
        body if redundant_begin_in_expressions?(body)
      end
    end

    private def first_begin_expression(node)
      return unless node.is_a?(Crystal::Expressions)
      return node if redundant_begin_in_expressions?(node)

      first = node.expressions.first?
      first if first.is_a?(Crystal::Expressions) && redundant_begin_in_expressions?(first)
    end

    private def redundant_begin_in_expressions?(node)
      !!node.keyword.try(&.begin?)
    end

    private def inner_handler?(handler)
      handler.body.is_a?(Crystal::ExceptionHandler)
    end

    private def begin_exprs_in_handler?(handler)
      return unless (body = handler.body).is_a?(Crystal::Expressions)
      body.expressions.first?.is_a?(Crystal::ExceptionHandler)
    end

    private def starts_line?(source, location)
      line = source.lines[location.line_number - 1]
      line[...location.column_number - 1].blank?
    end

    private def exception_handler_allowed?(source, node)
      case node
      in Crystal::Def
        # Proc literals are represented as a `Def` named `->`
        node.name != "->"
      in Crystal::Block
        # Blocks using curly braces cannot have exception handlers
        !!node_source(node, source.lines).try { |code| !code.starts_with?('{') }
      end
    end
  end
end
