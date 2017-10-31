module Ameba
  RULES = [
    Rules::LineLength,
    Rules::TrailingBlankLines,
    Rules::TrailingWhitespace,
  ]

  macro rule(name, &block)
    module Ameba::Rules
      struct {{name.id}} < Rule
        def test(source)
          {{block.body}}
        end
      end
    end
  end

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
