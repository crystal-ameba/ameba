module Ameba::Rule
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
  # YAML configuration example:
  #
  # ```
  # RedundantBegin:
  #   Enabled: true
  # ```
  #
  struct RedundantBegin < Base
    include AST::Util

    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::Def)
      return unless redundant_begin?(source, node)

      source.error self, node.location, "Redundant `begin` block detected."
    end

    private def redundant_begin?(source, node)
      case body = node.body
      when Crystal::ExceptionHandler
        redundant_begin_in_handler?(source, body, node)
      when Crystal::Expressions
        redundant_begin_in_expressions?(body)
      end
    end

    private def redundant_begin_in_expressions?(node)
      node.keyword == :begin
    end

    private def redundant_begin_in_handler?(source, handler, node)
      return false if begin_exprs_in_handler?(handler)

      code = node_source(node, source.lines).try &.join("\n")
      def_redundant_begin? code if code
    rescue
      false
    end

    private def begin_exprs_in_handler?(handler)
      if (body = handler.body).is_a?(Crystal::Expressions)
        exception_handler?(body.expressions.first)
      end
    end

    private def def_redundant_begin?(code)
      lexer = Crystal::Lexer.new code
      in_body? = in_argument_list? = false
      while true
        token = lexer.next_token

        case token.type
        when :EOF
          break
        when :IDENT
          return token.value == :begin if in_body?
        when :"("
          in_argument_list? = true
        when :")"
          in_argument_list? = false
        when :NEWLINE
          in_body? = true unless in_argument_list?
        when :SPACE
        else
          return false if in_body?
        end
      end
    end
  end
end
