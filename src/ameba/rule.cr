module Ameba
  abstract struct Rule
    abstract def test(source : Source)

    def test(source : Source, node : Crystal::ASTNode)
      # can't be abstract
    end

    def catch(source : Source)
      source.tap { |s| test s }
    end

    def name
      self.class.name.gsub("Ameba::Rules::", "")
    end

    def self.rules
      {{ @type.subclasses }}
    end
  end
end
