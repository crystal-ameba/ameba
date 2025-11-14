module Ameba::Rule::Lint
  # A rule that reports conflicting enum member names.
  #
  # Since Crystal will parse enum member names using `String#camelcase` and
  # `String#downcase`, it is important to ensure that each member has a name
  # that stays unique after the transformation.
  #
  # ```
  # enum Foo
  #   Bar
  #   BAR
  # end
  #
  # Foo.parse("bar") # => Foo::Bar
  # Foo.parse("Bar") # => Foo::Bar
  # Foo.parse("BAR") # => Foo::Bar
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/EnumMemberNameConflict:
  #   Enabled: true
  # ```
  class EnumMemberNameConflict < Base
    properties do
      since_version "1.7.0"
      description "Reports conflicting enum member names"
    end

    MSG = "Enum member name conflict detected"

    def test(source, node : Crystal::EnumDef)
      found_names = Set(String).new

      node.members.each do |member|
        next unless member.is_a?(Crystal::Arg)
        next if found_names.add?(member.name.camelcase.downcase)

        issue_for member, MSG, prefer_name_location: true
      end
    end
  end
end
