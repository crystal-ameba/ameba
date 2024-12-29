module Ameba::Rule::Typing
  # A rule that enforces variable arguments to specific macros have a type restriction.
  #
  # For example, these are considered invalid:
  #
  # ```
  # class Greeter
  #   getter name
  # end
  #
  # record Task,
  #   cmd : String,
  #   args = %w[]
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # class Greeter
  #   getter name : String?
  #   class_getter age : Int32 = 0
  # end
  #
  # record Task,
  #   cmd : String,
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
  #   Enabled: false
  #   DefaultValue: true
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
      description "Recommends that variable args to certain macros have type restrictions"
      enabled false
      default_value true
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

          issue_for arg.target, MSG % node.name, prefer_name_location: true
        when Crystal::Var, Crystal::Call
          issue_for arg, MSG % node.name, prefer_name_location: true
        end
      end
    end
  end
end
