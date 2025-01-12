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
  # The `BlockParam` configuration option will extend this to block params, where these are invalid:
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
  #   Enabled: false
  #   DefaultValue: false
  #   PrivateMethods: false
  #   ProtectedMethods: false
  #   BlockParam: false
  # ```
  class MethodParameterTypeRestriction < Base
    properties do
      since_version "1.7.0"
      description "Recommends that method parameters have type restrictions"
      enabled false
      default_value false
      private_methods false
      protected_methods false
      block_parameters false
    end

    MSG = "Method parameter should have a type restriction"

    def test(source, node : Crystal::Def)
      return if valid?(node)

      node.args.each do |arg|
        next if arg.restriction || arg.name.empty? || (!default_value? && arg.default_value)

        issue_for arg, MSG
      end

      if block_parameters?
        node.block_arg.try do |block_arg|
          next if block_arg.restriction

          issue_for block_arg, MSG
        end
      end
    end

    private def valid?(node : Crystal::ASTNode) : Bool
      (!private_methods? && node.visibility.private?) ||
        (!protected_methods? && node.visibility.protected?)
    end
  end
end
