module Ameba::Rule::Lint
  # A rule that disallows method, macro, and block parameter names
  # ending with `?` or `!`.
  #
  # The Crystal compiler emits a warning for such parameter names because
  # identifiers ending with `?` or `!` are reserved for method names and
  # predicates, causing syntactic ambiguities when accessed as local variables.
  #
  # For example, these are considered invalid:
  #
  # ```
  # def foo(bar?)
  # end
  #
  # macro foo(bar!)
  # end
  #
  # items.each do |item?|
  # end
  # ```
  #
  # And should be written as:
  #
  # ```
  # def foo(bar)
  # end
  #
  # macro foo(bar)
  # end
  #
  # items.each do |item|
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/InvalidParameterName:
  #   Enabled: true
  # ```
  class InvalidParameterName < Base
    properties do
      since_version "1.7.1"
      description "Disallows method, macro, and block parameter names ending with `?` or `!`"
    end

    MSG = "Invalid parameter name `%s`"

    def test(source)
      InvalidParameterNameVisitor.new(self, source) do |node, name|
        issue_for(node, MSG % name, prefer_name_location: true)
      end
    end

    private class InvalidParameterNameVisitor < AST::BaseVisitor
      def initialize(rule, source, &@on_invalid_param : (Crystal::ASTNode, String) ->)
        super(rule, source)
      end

      def visit(node : Crystal::Def)
        return false if node.name == "->"

        check_args(node.args)
        check_arg(node.double_splat)
        check_arg(node.block_arg)
        true
      end

      def visit(node : Crystal::Macro)
        check_args(node.args)
        check_arg(node.double_splat)
        check_arg(node.block_arg)
        true
      end

      def visit(node : Crystal::Block)
        node.args.each do |arg|
          check_param_name(arg, arg.name)
        end

        node.unpacks.try &.each_value do |expressions|
          check_unpacks(expressions)
        end
        true
      end

      private def check_args(args : Array(Crystal::Arg))
        args.each { |arg| check_arg(arg) }
      end

      private def check_arg(arg : Crystal::Arg?)
        return unless arg

        check_param_name(arg, arg.name)
      end

      private def check_unpacks(node : Crystal::ASTNode)
        case node
        when Crystal::Var
          check_param_name(node, node.name)
        when Crystal::Expressions
          node.expressions.each { |exp| check_unpacks(exp) }
        end
      end

      private def check_param_name(node : Crystal::ASTNode, name : String)
        return if name.blank?
        return unless name.ends_with?('?') || name.ends_with?('!')

        @on_invalid_param.call(node, name)
      end
    end
  end
end
