module Ameba::Rule::Lint
  # A rule that reports unused arguments.
  # For example, this is considered invalid:
  #
  # ```
  # def method(a, b, c)
  #   a + b
  # end
  # ```
  #
  # and should be written as:
  #
  # ```
  # def method(a, b)
  #   a + b
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedArgument:
  #   Enabled: true
  #   IgnoreDefs: true
  #   IgnoreBlocks: false
  #   IgnoreProcs: false
  # ```
  class UnusedArgument < Base
    properties do
      description "Disallows unused arguments"

      ignore_defs true
      ignore_blocks false
      ignore_procs false
    end

    MSG = "Unused argument `%s`. If it's necessary, use `%s` " \
          "as an argument name to indicate that it won't be used."

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node : Crystal::ProcLiteral, scope : AST::Scope)
      ignore_procs? || find_unused_arguments(source, scope)
    end

    def test(source, node : Crystal::Block, scope : AST::Scope)
      ignore_blocks? || find_unused_arguments(source, scope)
    end

    def test(source, node : Crystal::Def, scope : AST::Scope)
      arguments = scope.arguments.dup

      # `Lint/UnusedBlockArgument` rule covers this case explicitly
      if block_arg = node.block_arg
        arguments.reject!(&.node.== block_arg)
      end

      ignore_defs? || find_unused_arguments(source, scope, arguments)
    end

    private def find_unused_arguments(source, scope, arguments = scope.arguments)
      arguments.each do |argument|
        next if argument.anonymous? || argument.ignored?
        next if scope.references?(argument.variable)

        name_suggestion = scope.node.is_a?(Crystal::Block) ? '_' : "_#{argument.name}"
        message = MSG % {argument.name, name_suggestion}

        location = argument.node.location
        end_location = location.try &.adjust(column_number: argument.name.size - 1)

        if location && end_location
          issue_for argument.node, message do |corrector|
            corrector.replace(location, end_location, name_suggestion)
          end
        else
          issue_for argument.node, message
        end
      end
    end
  end
end
