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
  # The config option `Undocumented` controls whether this rule applies to undocumented methods and methods with a `:nodoc:` directive.
  #
  # YAML configuration example:
  #
  # ```
  # Typing/MethodReturnTypeRestriction:
  #   Enabled: true
  #   Undocumented: true
  #   PrivateMethods: true
  #   ProtectedMethods: true
  # ```
  class MethodReturnTypeRestriction < Base
    properties do
      description "Recommends that methods have a return type restriction"
      enabled false
      undocumented false
      private_methods false
      protected_methods false
    end

    MSG = "Methods should have a return type restriction"

    def test(source, node : Crystal::Def)
      return if node.return_type || check_config(node)

      issue_for node, MSG, prefer_name_location: true
    end

    def check_config(node : Crystal::ASTNode) : Bool
      (!private_methods? && node.visibility.private?) ||
        (!protected_methods? && node.visibility.protected?) ||
        (!undocumented? && (node.doc.nil? || node.doc.try(&.starts_with?(":nodoc:")))) ||
        false
    end
  end
end
