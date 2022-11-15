module Ameba::Rule::Style
  # A rule that disallows redundant begin blocks.
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
  # 2. begin..end block as a top level block in a method.
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
      description "Disallows redundant begin blocks"
    end

    MSG = "Redundant `begin` block detected"

    def test(source, node : Crystal::Def)
      return unless def_loc = node.location

      case body = node.body
      when Crystal::ExceptionHandler
        return if begin_exprs_in_handler?(body) || inner_handler?(body)
      when Crystal::Expressions
        return unless redundant_begin_in_expressions?(body)
      else
        return
      end

      return unless begin_range = def_redundant_begin_range(source, node)

      begin_loc, end_loc = begin_range
      begin_loc, end_loc = def_loc.seek(begin_loc), def_loc.seek(end_loc)
      begin_end_loc = begin_loc.adjust(column_number: {{ "begin".size - 1 }})
      end_end_loc = end_loc.adjust(column_number: {{ "end".size - 1 }})

      issue_for begin_loc, begin_end_loc, MSG do |corrector|
        corrector.remove(begin_loc, begin_end_loc)
        corrector.remove(end_loc, end_end_loc)
      end
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

    private def def_redundant_begin_range(source, node)
      return unless code = node_source(node, source.lines)

      lexer = Crystal::Lexer.new code
      return unless begin_loc = def_redundant_begin_loc(lexer)
      return unless end_loc = def_redundant_end_loc(lexer)

      {begin_loc, end_loc}
    end

    private def def_redundant_begin_loc(lexer)
      in_body = in_argument_list = false

      loop do
        token = lexer.next_token

        case token.type
        when .eof?, .op_minus_gt?
          break
        when .ident?
          next unless in_body
          return unless token.value == Crystal::Keyword::BEGIN
          return token.location
        when .op_lparen?
          in_argument_list = true
        when .op_rparen?
          in_argument_list = false
        when .newline?
          in_body = true unless in_argument_list
        when .space?
          # ignore
        else
          return if in_body
        end
      end
    end

    private def def_redundant_end_loc(lexer)
      end_loc = def_end_loc = nil

      Tokenizer.new(lexer).run do |token|
        next unless token.value == Crystal::Keyword::END

        end_loc, def_end_loc = def_end_loc, token.location
      end

      end_loc
    end
  end
end
