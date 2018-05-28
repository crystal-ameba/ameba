module Ameba::Rule
  # A rule that disallows shadowed arguments.
  #
  # For example, this is considered invalid:
  #
  # ```
  # do_something do |foo|
  #   foo = 1 # shadows block argument
  #   foo
  # end
  #
  # def do_something(foo)
  #   foo = 1 # shadows method argument
  #   foo
  # end
  # ```
  #
  # and it should be written as follows:
  #
  # ```
  # do_something do |foo|
  #   foo = foo + 42
  #   foo
  # end
  #
  # def do_something(foo)
  #   foo = foo + 42
  #   foo
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # ShadowedArgument:
  #   Enabled: true
  # ```
  #
  struct ShadowedArgument < Base
    properties do
      description "Disallows shadowed arguments"
    end

    MSG = "Argument `%s` is assigned before it is used"

    def test(source)
      AST::ScopeVisitor.new self, source
    end

    def test(source, node, scope : AST::Scope)
      scope.arguments.each do |arg|
        next unless assign = arg.variable.assign_before_reference

        source.error self, assign.location, MSG % arg.name
      end
    end
  end
end
