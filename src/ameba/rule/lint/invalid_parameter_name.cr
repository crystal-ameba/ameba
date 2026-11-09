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
    include AST::Util

    properties do
      since_version "1.8.0"
      description "Disallows method, macro, and block parameter names ending with `?` or `!`"
    end

    MSG = "Invalid parameter name `%s`"

    def test(source, node : Crystal::Def | Crystal::Macro)
      node.args.each { |arg| check_arg(source, arg) }
      check_arg(source, node.double_splat)
      check_arg(source, node.block_arg)
    end

    def test(source, node : Crystal::Block)
      all_block_args(node).each { |arg| check_arg(source, arg) }
    end

    private def check_arg(source, arg)
      return unless arg
      return unless (name = arg.name).ends_with?('?') || name.ends_with?('!')

      issue_for(arg, MSG % name, prefer_name_location: true)
    end
  end
end
