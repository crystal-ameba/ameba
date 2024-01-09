module Ameba::Rule
  # List of names of the special rules, which
  # behave differently than usual rules.
  SPECIAL = {
    Lint::Syntax.rule_name,
    Lint::UnneededDisableDirective.rule_name,
  }

  # Represents a base of all rules. In other words, all rules
  # inherits from this struct:
  #
  # ```
  # class MyRule < Ameba::Rule::Base
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
  abstract class Base
    include Config::RuleConfig

    # This method is designed to test the source passed in. If source has issues
    # that are tested by this rule, it should add an issue.
    #
    # By default it uses a node visitor to traverse all the nodes in the source.
    #
    # NOTE: Must be overridden for other type of rules.
    def test(source : Source)
      AST::NodeVisitor.new self, source
    end

    # NOTE: Can't be abstract
    def test(source : Source, node : Crystal::ASTNode, *opts)
    end

    # A convenient addition to `#test` method that does the same
    # but returns a passed in `source` as an addition.
    #
    # ```
    # source = MyRule.new.catch(source)
    # source.valid?
    # ```
    def catch(source : Source)
      source.tap { test source }
    end

    # Returns a name of this rule, which is basically a class name.
    #
    # ```
    # class MyRule < Ameba::Rule::Base
    #   def test(source)
    #   end
    # end
    #
    # MyRule.new.name # => "MyRule"
    # ```
    def name
      {{ @type }}.rule_name
    end

    # Returns a group this rule belong to.
    #
    # ```
    # class MyGroup::MyRule < Ameba::Rule::Base
    #   # ...
    # end
    #
    # MyGroup::MyRule.new.group # => "MyGroup"
    # ```
    def group
      {{ @type }}.group_name
    end

    # Checks whether the source is excluded from this rule.
    # It searches for a path in `excluded` property which matches
    # the one of the given source.
    #
    # ```
    # my_rule.excluded?(source) # => true or false
    # ```
    def excluded?(source)
      !!excluded.try &.any? do |path|
        source.matches_path?(path) ||
          Dir.glob(path).any? { |glob| source.matches_path?(glob) }
      end
    end

    # Returns `true` if this rule is special and behaves differently than
    # usual rules.
    #
    # ```
    # my_rule.special? # => true or false
    # ```
    def special?
      name.in?(SPECIAL)
    end

    def ==(other)
      name == other.try(&.name)
    end

    def hash
      name.hash
    end

    # Adds an issue to the *source*
    macro issue_for(*args, **kwargs, &block)
      source.add_issue(self, {{ args.splat }}, {{ kwargs.double_splat }}) {{ block }}
    end

    protected def self.rule_name
      name.gsub("Ameba::Rule::", "").gsub("::", '/')
    end

    protected def self.group_name
      rule_name.split('/')[0...-1].join('/')
    end

    protected def self.subclasses
      {{ @type.subclasses }}
    end

    protected def self.abstract?
      {{ @type.abstract? }}
    end

    protected def self.inherited_rules
      subclasses.each_with_object([] of Base.class) do |klass, obj|
        klass.abstract? ? obj.concat(klass.inherited_rules) : (obj << klass)
      end
    end

    private macro read_type_doc(filepath = __FILE__)
      {{ run("../../contrib/read_type_doc",
           @type.name.split("::").last,
           filepath
         ).chomp.stringify }}.presence
    end

    macro inherited
      # Returns documentation for this rule, if there is any.
      #
      # ```
      # module Ameba
      #   # This is a test rule.
      #   # Does nothing.
      #   class MyRule < Ameba::Rule::Base
      #     def test(source)
      #     end
      #   end
      # end
      #
      # MyRule.parsed_doc # => "This is a test rule.\nDoes nothing."
      # ```
      class_getter parsed_doc : String? = read_type_doc
    end
  end

  # Returns a list of all available rules.
  #
  # ```
  # Ameba::Rule.rules # => [Rule1, Rule2, ....]
  # ```
  def self.rules
    Base.inherited_rules
  end
end
