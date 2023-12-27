require "../../../spec_helper"

module Ameba::AST
  describe FlowExpressionVisitor do
    it "creates an expression for return" do
      rule = FlowExpressionRule.new
      FlowExpressionVisitor.new rule, Source.new <<-CRYSTAL
        def foo
          return :bar
        end
        CRYSTAL
      rule.expressions.size.should eq 1
    end

    it "can create multiple expressions" do
      rule = FlowExpressionRule.new
      FlowExpressionVisitor.new rule, Source.new <<-CRYSTAL
        def foo
          if bar
            return :baz
          else
            return :foobar
          end
        end
        CRYSTAL
      rule.expressions.size.should eq 3
    end

    it "properly creates nested flow expressions" do
      rule = FlowExpressionRule.new
      FlowExpressionVisitor.new rule, Source.new <<-CRYSTAL
        def foo
          return (
            loop do
              break if a > 1
              return a
            end
          )
        end
        CRYSTAL
      rule.expressions.size.should eq 4
    end

    it "creates an expression for break" do
      rule = FlowExpressionRule.new
      FlowExpressionVisitor.new rule, Source.new <<-CRYSTAL
        while true
          break
        end
        CRYSTAL
      rule.expressions.size.should eq 1
    end

    it "creates an expression for next" do
      rule = FlowExpressionRule.new
      FlowExpressionVisitor.new rule, Source.new <<-CRYSTAL
        while true
          next if something
        end
        CRYSTAL
      rule.expressions.size.should eq 1
    end
  end
end
