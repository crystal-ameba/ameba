module Ameba::Rule::Lint
  # A rule that disallows unused instance variable access.
  #
  # For example, this is considered invalid:
  #
  # ```
  # class MyClass
  #   @my_var : String = "hello"
  #
  #   @my_var
  #
  #   def hello : String
  #     @my_var
  #
  #     "hello, world!"
  #   end
  # end
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # class MyClass
  #   @my_var : String = "hello"
  #
  #   @my_other_var = @my_var
  #
  #   def hello : String
  #     return @my_var if @my_var == "hello"
  #
  #     "hello, world!"
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedInstanceVariableAccess:
  #   Enabled: true
  # ```
  class UnusedInstanceVariableAccess < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused access to instance variables"
    end

    MSG = "Value from instance variable access is unused"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::InstanceVar, in_macro : Bool)
      # Handle special case when using `@type` within a method body has side-effects
      return if in_macro && node.name == "@type"

      issue_for node, MSG
    end
  end
end
