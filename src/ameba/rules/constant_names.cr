module Ameba::Rules
  # A rule that enforces constant names to be in screaming case.
  #
  # For example, these constant names are considered valid:
  #
  # ```
  # LUCKY_NUMBERS     = [3, 7, 11]
  # DOCUMENTATION_URL = "http://crystal-lang.org/docs"
  # ```
  #
  # And these are invalid names:
  #
  # ```
  # MyBadConstant = 1
  # Wrong_NAME    = 2
  # ```
  #
  struct ConstantNames < Rule
    def test(source)
      AST::Visitor.new self, source
    end

    def test(source, node : Crystal::Assign)
      if (target = node.target).is_a? Crystal::Path
        name = target.names.first
        return if (expected = name.upcase) == name

        source.error self, node.location,
          "Constant name should be screaming-cased: #{expected}, not #{name}"
      end
    end
  end
end
