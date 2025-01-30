module Ameba::Rule::Typing
  # A rule that enforces call arguments to specific macros have a type restriction.
  # By default these macros are: `(class_)getter/setter/property(?/!)` and `record`.
  #
  # For example, these are considered invalid:
  #
  # ```
  # class Greeter
  #   getter name
  #   getter age = 0.days
  #   getter :height
  # end
  #
  # record Task,
  #   cmd = "",
  #   args = %w[]
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # class Greeter
  #   getter name : String?
  #   getter age : Time::Span = 0.days
  #   getter height : Float64?
  # end
  #
  # record Task,
  #   cmd : String = "",
  #   args : Array(String) = %w[]
  # ```
  #
  # The `DefaultValue` configuration option controls whether this rule applies to
  # call arguments that have a default value.
  #
  # YAML configuration example:
  #
  # ```
  # Typing/MacroCallArgumentTypeRestriction:
  #   Enabled: true
  #   DefaultValue: false
  #   MacroNames:
  #    - getter
  #    - getter?
  #    - getter!
  #    - class_getter
  #    - class_getter?
  #    - class_getter!
  #    - setter
  #    - setter?
  #    - setter!
  #    - class_setter
  #    - class_setter?
  #    - class_setter!
  #    - property
  #    - property?
  #    - property!
  #    - class_property
  #    - class_property?
  #    - class_property!
  #    - record
  # ```
  class MacroCallArgumentTypeRestriction < Base
    properties do
      since_version "1.7.0"
      description "Recommends that call arguments to certain macros have type restrictions"
      enabled false
      default_value false
      macro_names %w[
        getter getter? getter! class_getter class_getter? class_getter!
        setter setter? setter! class_setter class_setter? class_setter!
        property property? property! class_property class_property? class_property!
        record
      ]
    end

    MSG = "Argument should have a type restriction"

    def test(source, node : Crystal::Call)
      return unless node.name.in?(macro_names)

      node.args.each do |arg|
        case arg
        when Crystal::Assign
          next unless default_value?

          issue_for arg.target, MSG
        when Crystal::Var, Crystal::Call, Crystal::StringLiteral, Crystal::SymbolLiteral
          issue_for arg, MSG
        end
      end
    end
  end
end
