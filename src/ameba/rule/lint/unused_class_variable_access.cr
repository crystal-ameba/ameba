module Ameba::Rule::Lint
  # A rule that disallows unused class variable access.
  #
  # For example, this is considered invalid:
  #
  # ```
  # class MyClass
  #   @@my_var : String = "hello"
  #
  #   @@my_var
  #
  #   def hello : String
  #     @@my_var
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
  #   @@my_var : String = "hello"
  #
  #   @@my_other_var = @@my_var
  #
  #   def hello : String
  #     return @@my_var if @@my_var == "hello"
  #
  #     "hello, world!"
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedClassVariableAccess:
  #   Enabled: true
  # ```
  class UnusedClassVariableAccess < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused access to class variables"
    end

    MSG = "Value from class variable access is unused"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::ClassVar, in_macro : Bool)
      # Class variables aren't supported in macros
      return if in_macro

      issue_for node, MSG
    end
  end
end
