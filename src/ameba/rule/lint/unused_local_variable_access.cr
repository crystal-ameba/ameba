module Ameba::Rule::Lint
  # A rule that disallows unused local variable access.
  #
  # For example, this is considered invalid:
  #
  # ```
  # a = 1
  # b = "2"
  # c = :3
  #
  # case method_call
  # when Int32
  #   a
  # when String
  #   b
  # else
  #   c
  # end
  #
  # def hello(name)
  #   if name.size < 10
  #     name
  #   end
  #
  #   name[...10]
  # end
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # a = 1
  # b = "2"
  # c = :3
  #
  # d = case method_call
  #     when Int32
  #       a
  #     when String
  #       b
  #     else
  #       c
  #     end
  #
  # def hello(name)
  #   if name.size < 10
  #     return name
  #   end
  #
  #   name[...10]
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedLocalVariableAccess:
  #   Enabled: true
  # ```
  class UnusedLocalVariableAccess < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused access to local variables"
    end

    MSG = "Value from local variable access is unused"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::Var, in_macro : Bool)
      # This case will be reported by `Lint/UnusedSelfAccess` rule
      return if node.name == "self"
      # Ignore `debug` and `skip_file` macro methods
      return if in_macro && node.name.in?("debug", "skip_file")

      issue_for node, MSG
    end
  end
end
