module Ameba
  RULES = [
    Rules::ComparisonToBoolean,
    Rules::LineLength,
    Rules::TrailingBlankLines,
    Rules::TrailingWhitespace,
    Rules::UnlessElse,
  ]

  abstract struct Rule
    abstract def test(source : Source)

    def test(source : Source, node : Crystal::ASTNode)
      raise "Unimplemented"
    end

    def catch(source : Source)
      source.tap { |s| test s }
    end

    def name
      self.class.name.gsub("Ameba::Rules::", "")
    end
  end
end
