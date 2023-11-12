module Ameba::Rule::Lint
  # A rule that disallows yielding method definitions without block argument.
  #
  # For example, this is considered invalid:
  #
  #     def foo
  #       yield 42
  #     end
  #
  # And has to be written as the following:
  #
  #     def foo(&)
  #       yield 42
  #     end
  #
  # YAML configuration example:
  #
  # ```
  # Lint/MissingBlockArgument:
  #   Enabled: true
  # ```
  class MissingBlockArgument < Base
    properties do
      description "Disallows yielding method definitions without block argument"
    end

    MSG = "Missing anonymous block argument. Use `&` as an argument " \
          "name to indicate yielding method."

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node : Crystal::Def, scope : AST::Scope)
      return if !scope.yields? || node.block_arg

      issue_for node, MSG, prefer_name_location: true
    end
  end
end
