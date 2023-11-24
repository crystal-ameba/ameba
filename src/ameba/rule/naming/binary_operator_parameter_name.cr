module Ameba::Rule::Naming
  # A rule that enforces that certain binary operator methods have
  # their sole parameter named `other`.
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
  # ```
  class BinaryOperatorParameterName < Base
    properties do
      description "Enforces that certain binary operator methods have " \
                  "their sole parameter named `other`"
      excluded_operators %w[[] []? []= << >> ` =~ !~]
    end

    MSG = "When defining the `%s` operator, name its argument `other`"

    def test(source, node : Crystal::Def)
      name = node.name

      return if name == "->" || name.in?(excluded_operators)
      return if name.chars.any?(&.alphanumeric?)
      return unless node.args.size == 1
      return if (arg = node.args.first).name == "other"

      issue_for arg, MSG % name
    end
  end
end
