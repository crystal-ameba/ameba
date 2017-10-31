module Ameba
  RULES = [
    Rules::LineLength,
    Rules::TrailingBlankLines,
    Rules::TrailingWhitespace,
    Rules::UnlessElse,
  ]

  abstract struct Rule
    abstract def test(source : Source)

    def catch(source : Source)
      source.tap { |s| test s }
    end

    def name
      self.class.name.gsub("Ameba::Rules::", "")
    end
  end
end
