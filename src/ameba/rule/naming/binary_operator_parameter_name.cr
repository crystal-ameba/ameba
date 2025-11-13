module Ameba::Rule::Naming
  # A rule that enforces that certain binary operator methods have
  # standardized parameter names - by default `other`.
  #
  # For example, this is considered valid:
  #
  # ```
  # class Money
  #   def +(other)
  #   end
  # end
  # ```
  #
  # And this is invalid parameter name:
  #
  # ```
  # class Money
  #   def +(amount)
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Naming/BinaryOperatorParameterName:
  #   Enabled: true
  #   ExcludedOperators: ["[]", "[]?", "[]=", "<<", ">>", "=~", "!~"]
  #   AllowedNames: [other]
  # ```
  class BinaryOperatorParameterName < Base
    include AST::Util

    properties do
      since_version "1.6.0"
      description "Enforces that certain binary operator methods have " \
                  "their sole parameter name standardized"
      excluded_operators %w[[] []? []= << >> ` =~ !~]
      allowed_names %w[other]
    end

    MSG = "When defining the `%s` operator, name its argument %s"

    def test(source, node : Crystal::Def)
      name = node.name

      return if !operator_method?(node) || name.in?(excluded_operators)
      return unless node.args.size == 1
      return if (arg = node.args.first).name.in?(allowed_names)

      opts =
        allowed_names.map { |val| "`#{val}`" }.join(" or ")

      issue_for arg, MSG % {name, opts}, prefer_name_location: true
    end
  end
end
