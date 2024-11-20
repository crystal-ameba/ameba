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
  #   Enabled: true
  #   PrivateMethods: true
  #   ProtectedMethods: true
  # ```
  class MethodReturnTypeRestriction < Base
    properties do
      description "Enforce methods have a return type restriction"
      enabled false
      private_methods true
      protected_methods true
    end

    MSG = "Methods require a return type restriction"

    def test(source, node : Crystal::Def)
      return if node.return_type ||
                (!private_methods? && node.visibility.private?) ||
                (!protected_methods? && node.visibility.protected?)

      issue_for node, MSG, prefer_name_location: true
    end
  end
end
