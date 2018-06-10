module Ameba::Rule
  # List of names of the special rules, which
  # behave differently than usual rules.
  SPECIAL = [
    Syntax.rule_name,
    UnneededDisableDirective.rule_name,
  ]

  # Represents a base of all rules. In other words, all rules
  # inherits from this struct:
  #
  # ```
  # struct MyRule < Ameba::Rule::Base
  #   def test(source)
  #     if invalid?(source)
  #       issue_for line, column, "Something wrong."
  #     end
  #   end
  #
  #   private def invalid?(source)
  #     # ...
  #   end
  # end
  # ```
  #
  # Enforces rules to implement an abstract `#test` method which
  # is designed to test the source passed in. If source has issues
  # that are tested by this rule, it should add an issue.
  #
  abstract struct Base
    include Config::RuleConfig

    # This method is designed to test the source passed in. If source has issues
    # that are tested by this rule, it should add an issue.
    abstract def test(source : Source)

    def test(source : Source, node : Crystal::ASTNode, *opts)
      # can't be abstract
    end

    # A convenient addition to `#test` method that does the same
    # but returns a passed in `source` as an addition.
    #
    # ```
    # source = MyRule.new.catch(source)
    # source.valid?
    # ```
    #
    def catch(source : Source)
      source.tap { |s| test s }
    end

    # Returns a name of this rule, which is basically a class name.
    #
    # ```
    # struct MyRule < Ameba::Rule::Base
    #   def test(source)
    #   end
    # end
    #
    # MyRule.new.name # => "MyRule"
    # ```
    #
    def name
      {{@type}}.rule_name
    end

    # Checks whether the source is excluded from this rule.
    # It searches for a path in `excluded` property which matches
    # the one of the given source.
    #
    # ```
    # my_rule.excluded?(source) # => true or false
    # ```
    #
    def excluded?(source)
      excluded.try &.any? do |path|
        source.matches_path?(path) ||
          Dir.glob(path).any? { |glob| source.matches_path? glob }
      end
    end

    # Returns true if this rule is special and behaves differently than
    # usual rules.
    #
    # ```
    # my_rule.special? # => true or false
    # ```
    #
    def special?
      SPECIAL.includes? name
    end

    macro issue_for(*args)
      source.add_issue self, {{*args}}
    end

    protected def self.rule_name
      name.gsub("Ameba::Rule::", "")
    end

    protected def self.subclasses
      {{ @type.subclasses }}
    end
  end

  # Returns a list of all available rules
  # (except a `Rule::Syntax` which is a special rule).
  #
  # ```
  # Ameba::Rule.rules # => [LineLength, ConstantNames, ....]
  # ```
  #
  def self.rules
    Base.subclasses
  end
end
