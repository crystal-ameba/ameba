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
      source.error self, 1, 1, "This rule always adds an error"
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
        str << "Source expected to be valid, but there are errors:\n\n"
        source.errors.each do |e|
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
