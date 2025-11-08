module Ameba::Rule::Lint
  # A rule that reports duplicated `enum` member values.
  #
  # ```
  # enum Foo
  #   Foo = 1
  #   Bar = 2
  #   Baz = 2 # duplicate value
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/DuplicateEnumValue:
  #   Enabled: true
  # ```
  class DuplicateEnumValue < Base
    properties do
      since_version "1.7.0"
      description "Reports duplicated `enum` member values"
    end

    MSG = "Duplicate enum member value detected"

    def test(source, node : Crystal::EnumDef)
      found_values = Set(String).new

      node.members.each do |member|
        next unless member.is_a?(Crystal::Arg)

        next unless value = member.default_value
        next if found_values.add?(value.to_s)

        issue_for value, MSG
      end
    end
  end
end
