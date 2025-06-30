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
  # The `NodocMethods` configuration option controls whether this rule applies to
  # methods with a `:nodoc:` directive.
  #
  # YAML configuration example:
  #
  # ```
  # Typing/MethodReturnTypeRestriction:
  #   Enabled: true
  #   PrivateMethods: false
  #   ProtectedMethods: false
  #   NodocMethods: false
  # ```
  class MethodReturnTypeRestriction < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Recommends that methods have a return type restriction"
      enabled false
      private_methods false
      protected_methods false
      nodoc_methods false
    end

    MSG = "Method should have a return type restriction"

    def test(source, node : Crystal::Def)
      issue_for node, MSG unless valid_return_type?(node)
    end

    private def valid_return_type?(node : Crystal::ASTNode) : Bool
      !!node.return_type ||
        (node.visibility.private? && !private_methods?) ||
        (node.visibility.protected? && !protected_methods?) ||
        (!nodoc_methods? && nodoc?(node))
    end
  end
end
