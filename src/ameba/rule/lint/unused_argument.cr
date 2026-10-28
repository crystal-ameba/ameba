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
      since_version "0.6.0"
      description "Disallows unused arguments"

      ignore_defs true
      ignore_blocks false
      ignore_procs false
    end

    MSG = "Unused argument `%s`. If it's necessary, use `%s` " \
          "as an argument name to indicate that it won't be used."

    def test(source)
      AST::ScopeVisitor.new(self, source)
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
        arguments.reject!(&.node.same?(block_arg))
      end

      ignore_defs? || find_unused_arguments(source, scope, arguments)
    end

    private def find_unused_arguments(source, scope, arguments = scope.arguments)
      arguments.each do |argument|
        next if argument.anonymous? || argument.ignored?
        next if scope.references?(argument.variable)

        name_suggestion = scope.node.is_a?(Crystal::Block) ? '_' : "_#{argument.name}"
        message = MSG % {argument.name, name_suggestion}

        node = argument.node

        location = node.location
        name_end_location = location.try(&.adjust(column_number: argument.name.size - 1))

        if node.responds_to?(:restriction)
          end_location = node.restriction.try(&.end_location)
        end
        end_location ||= name_end_location

        # Parameters can be passed by name, so we keep their external name
        replacement =
          if named_parameter?(scope, node)
            "#{argument.name} #{name_suggestion}"
          else
            name_suggestion.to_s
          end

        if location && name_end_location && end_location
          issue_for(location, end_location, message) do |corrector|
            corrector.replace(location, name_end_location, replacement)
          end
        else
          issue_for(node, message)
        end
      end
    end

    # Returns `true` if the *node* is a method parameter, which can be passed
    # by name, and has no explicit external name (i.e. `bar` in `def foo(bar)`).
    private def named_parameter?(scope, node)
      return false unless (def_node = scope.node).is_a?(Crystal::Def)
      return false unless node.is_a?(Crystal::Arg) && node.external_name == node.name
      return false if def_node.double_splat.same?(node)

      !(splat_index = def_node.splat_index) ||
        !def_node.args[splat_index]?.same?(node)
    end
  end
end
