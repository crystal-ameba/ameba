module Ameba::Rule::Typing
  # A rule that enforces method parameters have type restrictions, with optional enforcement of block parameters.
  #
  # For example, this is considered invalid:
  #
  # ```
  # def add(a, b)
  #   a + b
  # end
  # ```
  #
  # And this is considered valid:
  #
  # ```
  # def add(a : String, b : String)
  #   a + b
  # end
  # ```
  #
  # When the config options `PrivateMethods` and `ProtectedMethods`
  # are true, this rule is also applied to private and protected methods, respectively.
  #
  # The `NodocMethods` configuration option controls whether this rule applies to
  # methods with a `:nodoc:` directive.
  #
  # The `BlockParameters` configuration option will extend this to block parameters, where these are invalid:
  #
  # ```
  # def exec(&)
  # end
  #
  # def exec(&block)
  # end
  # ```
  #
  # And this is valid:
  #
  # ```
  # def exec(&block : String -> String)
  #   yield "cmd"
  # end
  # ```
  #
  # The config option `DefaultValue` controls whether this rule applies to parameters that have a default value.
  #
  # YAML configuration example:
  #
  # ```
  # Typing/MethodParameterTypeRestriction:
  #   Enabled: true
  #   DefaultValue: false
  #   BlockParameters: false
  #   PrivateMethods: false
  #   ProtectedMethods: false
  #   NodocMethods: false
  # ```
  class MethodParameterTypeRestriction < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Recommends that method parameters have type restrictions"
      enabled false
      default_value false
      block_parameters false
      private_methods false
      protected_methods false
      nodoc_methods false
    end

    MSG = "Method parameter should have a type restriction"

    def test(source, node : Crystal::Def)
      return if valid_visibility?(node)

      node.args.each do |arg|
        next if arg.restriction || arg.name.empty?
        next if !default_value? && arg.default_value

        issue_for arg, MSG
      end

      if block_parameters? && (block_arg = node.block_arg) && !block_arg.restriction
        issue_for block_arg, MSG
      end
    end

    private def valid_visibility?(node : Crystal::ASTNode) : Bool
      (!private_methods? && node.visibility.private?) ||
        (!protected_methods? && node.visibility.protected?) ||
        (!nodoc_methods? && nodoc?(node))
    end
  end
end
