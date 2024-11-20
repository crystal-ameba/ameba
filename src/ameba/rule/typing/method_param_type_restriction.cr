module Ameba::Rule::Typing
  # A rule that enforces method parameters have type restrictions, with optional enforcement of block parameters
  #
  # For example, these are considered valid:
  #
  # ```
  # def listen(a : String, b : String) : String
  #   a + b
  # end
  #
  # def hello(name : String?)
  #   puts "Hello, " + (name || "there") + "!"
  # end
  # ```
  #
  # And these are considered invalid:
  #
  # ```
  # def listen(a, b) : String
  #   a + b
  # end
  #
  # def hello(name)
  #   puts "Hello, " + (name || "there") + "!"
  # end
  # ```
  #
  # When the config options `PrivateMethods` and `ProtectedMethods`
  # are true, this rule is also applied to private and protected methods, respectively.
  #
  # The `BlockParam` configuration option will extend this to block params, where this is valid:
  #
  # ```
  # def exec(&block : String -> String)
  #   yield "cmd"
  # end
  # ```
  #
  # And these are invalid:
  #
  # ```
  # def exec(&)
  # end
  #
  # def exec(&block)
  # end
  # ```
  #
  # The config option `Undocumented` controls whether this rule applies to undocumented methods and methods with a `:nodoc:` directive.
  #
  # The config option `DefaultValue` controls whether this rule applies to parameters that have a default value.
  #
  # YAML configuration example:
  #
  # ```
  # Typing/MethodParamTypeRestriction:
  #   Enabled: true
  #   DefaultValue: true
  #   Undocumented: true
  #   PrivateMethods: true
  #   ProtectedMethods: true
  #   BlockParam: false
  # ```
  class MethodParamTypeRestriction < Base
    properties do
      description "Enforce method parameters have type restrictions"
      enabled false
      default_value false
      undocumented false
      private_methods false
      protected_methods false
      block_param false
    end

    MSG = "Method parameters require a type restriction"

    def test(source, node : Crystal::Def)
      return if check_config(node)

      node.args.each do |arg|
        next if arg.restriction || (!default_value? && arg.default_value)

        issue_for arg, MSG, prefer_name_location: true
      end

      if block_param?
        node.block_arg.try do |block_arg|
          next if block_arg.restriction

          issue_for block_arg, MSG, prefer_name_location: true
        end
      end
    end

    def check_config(node : Crystal::ASTNode) : Bool
      (!private_methods? && node.visibility.private?) ||
        (!protected_methods? && node.visibility.protected?) ||
        (!undocumented? && (node.doc.nil? || node.doc.try(&.starts_with?(":nodoc:")))) ||
        false
    end
  end
end
