module Ameba::Rule
  # A rule that reports unused arguments.
  # For example, this is considered invalid:
  #
  # ```
  # def method(a, b, c)
  #   a + b
  # end
  # ```
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
  # UnusedArgument:
  #   Enabled: true
  # ```
  #
  struct UnusedArgument < Base
    properties do
      description "Disallows unused arguments"
    end

    MSG = "Unused argument `%s`"

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, _node : Crystal::ProcLiteral, scope : AST::Scope)
      find_unused_arguments source, scope
    end

    def test(source, _node : Crystal::Block, scope : AST::Scope)
      find_unused_arguments source, scope
    end

    def test(source, _node : Crystal::Def, scope : AST::Scope)
      find_unused_arguments source, scope
    end

    private def find_unused_arguments(source, scope)
      scope.arguments.each do |argument|
        next if argument.ignored? || scope.references?(argument.variable)

        source.error self, argument.location, MSG % argument.name
      end
    end
  end
end
