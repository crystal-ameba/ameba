module Ameba::Rule::Lint
  # A rule that reports unused block arguments.
  # For example, this is considered invalid:
  #
  # ```
  # def foo(a, b, &block)
  #   a + b
  # end
  #
  # def bar(&block)
  #   yield 42
  # end
  # ```
  #
  # and should be written as:
  #
  # ```
  # def foo(a, b, &_block)
  #   a + b
  # end
  #
  # def bar(&)
  #   yield 42
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedBlockArgument:
  #   Enabled: true
  # ```
  class UnusedBlockArgument < Base
    properties do
      description "Disallows unused block arguments"
    end

    MSG_UNUSED = "Unused block argument `%1$s`. If it's necessary, use `_%1$s` " \
                 "as an argument name to indicate that it won't be used."

    MSG_YIELDED = "Use `&` as an argument name to indicate that it won't be referenced."

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node : Crystal::Def, scope : AST::Scope)
      return if node.abstract?

      return unless block_arg = node.block_arg
      return unless block_arg = scope.arguments.find(&.node.== block_arg)

      return if block_arg.anonymous?
      return if scope.references?(block_arg.variable)

      location = block_arg.node.location
      end_location = location.try &.adjust(column_number: block_arg.name.size - 1)

      case
      when scope.yields?
        if location && end_location
          issue_for location, end_location, MSG_YIELDED do |corrector|
            corrector.remove(location, end_location)
          end
        else
          issue_for block_arg.node, MSG_YIELDED
        end
      when !block_arg.ignored?
        if location && end_location
          issue_for location, end_location, MSG_UNUSED % block_arg.name do |corrector|
            corrector.insert_before(location, '_')
          end
        else
          issue_for block_arg.node, MSG_UNUSED % block_arg.name
        end
      end
    end
  end
end
