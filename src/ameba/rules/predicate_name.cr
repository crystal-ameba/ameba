module Ameba::Rules
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
  struct PredicateName < Rule
    def test(source)
      AST::DefVisitor.new self, source
    end

    def test(source, node : Crystal::Def)
      if node.name =~ /(is|has)_(\w+)\?/
        source.error self, node.location.try &.line_number,
          "Favour method name '#{$2}?' over '#{node.name}'"
      end
    end
  end
end
