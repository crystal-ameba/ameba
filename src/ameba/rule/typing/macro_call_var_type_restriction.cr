module Ameba::Rule::Typing
  # A rule that enforces variable arguments to certain macros have a type restriction.
  #
  # For example, these are considered valid:
  #
  # ```
  # class Greeter
  #   getter name : String?
  #   class_getter age : Int32 = 0
  #   setter tasks : Array(String) = [] of String
  #   class_setter queue : Array(Int32)?
  #   property task_mutex : Mutex = Mutex.new
  #   class_property asdf : String

  #   record Task,
  #     var1 : String,
  #     var2 : String = "asdf"
  # end
  # ```
  #
  # And these are considered invalid:
  #
  # ```
  # class Greeter
  #   getter name
  #
  #   record Task,
  #     var1 : String,
  #     var2 = "asdf"
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Typing/MethodParamTypeRestriction:
  #   Enabled: true
  #   MacroNames:
  #    - getter
  #    - setter
  #    - property
  #    - class_getter
  #    - class_setter
  #    - class_property
  #    - record
  # ```
  class MacroCallVarTypeRestriction < Base
    properties do
      description "Recommends that variable args to certain macros have type restrictions"
      enabled false
      macro_names %w(
        getter getter? getter! class_getter class_getter? class_getter!
        setter setter? setter! class_setter class_setter? class_setter!
        property property? property! class_property class_property? class_property!
        record
      )
    end

    MSG = "Variable arguments to `%s` should have a type restriction"

    def test(source, node : Crystal::Call)
      return unless node.name.in?(macro_names)

      node.args.each do |arg|
        case arg
        when Crystal::Assign
          issue_for arg.target, MSG % {node.name}, prefer_name_location: true
        when Crystal::Path, Crystal::TypeDeclaration # Allowed
        else
          issue_for arg, MSG % {node.name}, prefer_name_location: true
        end
      end
    end
  end
end
