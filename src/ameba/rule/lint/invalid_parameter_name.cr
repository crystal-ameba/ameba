module Ameba::Rule::Lint
  # A rule that disallows method, macro, and block parameter names
  # ending with `?` or `!`.
  #
  # The Crystal compiler emits a warning for such parameter names because
  # identifiers ending with `?` or `!` are reserved for method names and
  # predicates, causing syntactic ambiguities when accessed as local variables.
  #
  # For example, this is considered invalid:
  #
  # ```
  # def foo(bar?)
  # end
  # ```
  #
  # And should be written as:
  #
  # ```
  # def foo(bar)
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
      since_version "1.8.0"
      description "Disallows method, macro, and block parameter names ending with `?` or `!`"
    end

    MSG = "Invalid parameter name `%s`"

    def test(source, node : Crystal::Def | Crystal::Macro)
      check_args(source, node.args)
      check_arg(source, node.double_splat)
      check_arg(source, node.block_arg)
    end

    def test(source, node : Crystal::Block)
      node.args.each do |arg|
        check_param_name(source, arg, arg.name)
      end

      node.unpacks.try &.each_value do |expressions|
        check_unpacks(source, expressions)
      end
    end

    private def check_args(source, args : Array(Crystal::Arg))
      args.each { |arg| check_arg(source, arg) }
    end

    private def check_arg(source, arg : Crystal::Arg?)
      return unless arg

      check_param_name(source, arg, arg.name)
    end

    private def check_unpacks(source, node : Crystal::ASTNode)
      case node
      when Crystal::Var
        check_param_name(source, node, node.name)
      when Crystal::Expressions
        node.expressions.each { |exp| check_unpacks(source, exp) }
      end
    end

    private def check_param_name(source, node : Crystal::ASTNode, name : String)
      return if name.blank?
      return unless name.ends_with?('?') || name.ends_with?('!')

      issue_for(node, MSG % name, prefer_name_location: true)
    end
  end
end
