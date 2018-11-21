require "spec"
require "../src/ameba"

module Ameba
  struct DummyRule < Rule::Base
    properties do
      description : String = "Dummy rule that does nothing."
    end

    def test(source)
    end
  end

  class Source
    def initialize(code : String, @path = "", normalize = true)
      @code = normalize ? normalize_source(code) : code
    end

    private def normalize_source(code, separator = "\n")
      lines = code.split(separator)

      # remove unneeded first and last blank lines if any
      lines.shift if lines[0].blank? && lines.size > 1
      lines.pop if lines[-1].blank? && lines.size > 1

      # find the minimum indentation
      min_indent = lines.min_of do |line|
        line.blank? ? code.size : line.size - line.lstrip.size
      end

      # remove the width of minimum indentation in each line
      lines
        .map! { |line| line.blank? ? line : line[min_indent..-1] }
        .join(separator)
    end
  end

  struct NamedRule < Rule::Base
    properties do
      description : String = "A rule with a custom name."
    end

    def test(source)
    end

    def self.name
      "BreakingRule"
    end
  end

  struct ErrorRule < Rule::Base
    def test(source)
      issue_for({1, 1}, "This rule always adds an error")
    end
  end

  struct ScopeRule < Rule::Base
    getter scopes = [] of AST::Scope

    def test(source)
    end

    def test(source, node : Crystal::ASTNode, scope : AST::Scope)
      @scopes << scope
    end
  end

  struct FlowExpressionRule < Rule::Base
    getter expressions = [] of AST::FlowExpression

    def test(source)
    end

    def test(source, node, flow_expression : AST::FlowExpression)
      @expressions << flow_expression
    end
  end

  class DummyFormatter < Formatter::BaseFormatter
    property started_sources : Array(Source)?
    property finished_sources : Array(Source)?
    property started_source : Source?
    property finished_source : Source?

    def started(sources)
      @started_sources = sources
    end

    def source_finished(source : Source)
      @started_source = source
    end

    def source_started(source : Source)
      @finished_source = source
    end

    def finished(sources)
      @finished_sources = sources
    end
  end

  struct BeValidExpectation
    def match(source)
      source.valid?
    end

    def failure_message(source)
      String.build do |str|
        str << "Source expected to be valid, but there are issues: \n\n"
        source.issues.reject(&.disabled?).each do |e|
          str << "  * #{e.rule.name}: #{e.message}\n"
        end
      end
    end

    def negative_failure_message(source)
      "Source expected to be invalid, but it is valid."
    end
  end

  class TestNodeVisitor < Crystal::Visitor
    NODES = [
      Crystal::Var,
      Crystal::Assign,
      Crystal::OpAssign,
      Crystal::MultiAssign,
      Crystal::Block,
      Crystal::Def,
      Crystal::If,
      Crystal::While,
      Crystal::MacroLiteral,
      Crystal::Expressions,
    ]

    def initialize(node)
      node.accept self
    end

    def visit(node : Crystal::ASTNode)
      true
    end

    {% for node in NODES %}
      {{getter_name = node.stringify.split("::").last.underscore + "_nodes"}}

      getter {{getter_name.id}} = [] of {{node}}

      def visit(node : {{node}})
        {{getter_name.id}} << node
        true
      end
    {% end %}
  end
end

def be_valid
  Ameba::BeValidExpectation.new
end

def as_node(source)
  Crystal::Parser.new(source).parse
end

def as_nodes(source)
  Ameba::TestNodeVisitor.new(as_node source)
end
