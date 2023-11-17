module Ameba::Rule::Naming
  # A rule that enforces type names in camelcase manner.
  #
  # For example, these are considered valid:
  #
  # ```
  # class ParseError < Exception
  # end
  #
  # module HTTP
  #   class RequestHandler
  #   end
  # end
  #
  # alias NumericValue = Float32 | Float64 | Int32 | Int64
  #
  # lib LibYAML
  # end
  #
  # struct TagDirective
  # end
  #
  # enum Time::DayOfWeek
  # end
  # ```
  #
  # And these are invalid type names
  #
  # ```
  # class My_class
  # end
  #
  # module HTT_p
  # end
  #
  # alias Numeric_value = Int32
  #
  # lib Lib_YAML
  # end
  #
  # struct Tag_directive
  # end
  #
  # enum Time_enum::Day_of_week
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Naming/TypeNames:
  #   Enabled: true
  # ```
  class TypeNames < Base
    properties do
      description "Enforces type names in camelcase manner"
    end

    MSG = "Type name should be camelcased: %s, but it was %s"

    def test(source, node : Crystal::Alias | Crystal::ClassDef | Crystal::ModuleDef | Crystal::LibDef | Crystal::EnumDef)
      name = node.name.to_s

      return if (expected = name.camelcase) == name

      issue_for node.name, MSG % {expected, name}
    end
  end
end
