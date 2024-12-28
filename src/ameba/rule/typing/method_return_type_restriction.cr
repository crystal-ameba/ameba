module Ameba::Rule::Typing
  # A rule that enforces method definitions have a return type restriction.
  #
  # For example, these are considered valid:
  #
  # ```
  # def hello : String
  #   "hello world"
  # end
  #
  # def listen(a, b) : Int32
  #   0
  # end
  # ```
  #
  # And these are considered invalid:
  #
  # ```
  # def hello
  #   "hello world"
  # end
  #
  # def listen(a, b)
  #   0
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
  #   Enabled: false
  #   PrivateMethods: false
  #   ProtectedMethods: false
  # ```
  class MethodReturnTypeRestriction < Base
    properties do
      description "Recommends that methods have a return type restriction"
      enabled false
      private_methods false
      protected_methods false
    end

    MSG = "Method should have a return type restriction"

    def test(source, node : Crystal::Def)
      return if node.return_type || valid?(node)

      issue_for node, MSG, prefer_name_location: true
    end

    def valid?(node : Crystal::ASTNode) : Bool
      (!private_methods? && node.visibility.private?) ||
        (!protected_methods? && node.visibility.protected?) ||
        false
    end
  end
end
