module Ameba::Rule
  # A rule that disallows tautological predicate names, meaning those that
  # start with the prefix `has_` or the prefix `is_`.
  #
  # Favour these:
  #
  # ```
  # def valid?(x)
  # end
  #
  # def picture?(x)
  # end
  # ```
  #
  # Over these:
  #
  # ```
  # def is_valid?(x)
  # end
  #
  # def has_picture?(x)
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # PredicateName:
  #   Enabled: true
  # ```
  #
  struct PredicateName < Base
    properties do
      description = "Disallows tautological predicate names"
    end

    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::Def)
      if node.name =~ /^(is|has)_(\w+)\?/
        source.error self, node.location,
          "Favour method name '#{$2}?' over '#{node.name}'"
      end
    end
  end
end
