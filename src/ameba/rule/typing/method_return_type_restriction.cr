module Ameba::Rule::Typing
  # A rule that enforces method definitions have a return type restriction.
  #
  # For example, this are considered invalid:
  #
  # ```
  # def hello(name = "World")
  #   "Hello #{name}"
  # end
  # ```
  #
  # And this is valid:
  #
  # ```
  # def hello(name = "World") : String
  #   "Hello #{name}"
  # end
  # ```
  #
  # When the config options `PrivateMethods` and `ProtectedMethods`
  # are true, this rule is also applied to private and protected methods, respectively.
  #
  # YAML configuration example:
  #
  # ```
  # Typing/MethodReturnTypeRestriction:
  #   Enabled: true
  #   PrivateMethods: false
  #   ProtectedMethods: false
  # ```
  class MethodReturnTypeRestriction < Base
    properties do
      since_version "1.7.0"
      description "Recommends that methods have a return type restriction"
      enabled false
      private_methods false
      protected_methods false
    end

    MSG = "Method should have a return type restriction"

    def test(source, node : Crystal::Def)
      issue_for node, MSG unless valid_return_type?(node)
    end

    private def valid_return_type?(node : Crystal::ASTNode) : Bool
      !!node.return_type ||
        (node.visibility.private? && !private_methods?) ||
        (node.visibility.protected? && !protected_methods?)
    end
  end
end
