require "../../../spec_helper"

module Ameba::AST
  describe ElseIfAwareNodeVisitor do
    rule = ElseIfRule.new
    subject = ElseIfAwareNodeVisitor.new rule, Source.new <<-CRYSTAL
      # rule.ifs[0]
      foo ? bar : baz

      def foo
        # rule.ifs[2]
        if :one
          1
        elsif :two
          2
        elsif :three
          3
        else
          %w[].each do
            # rule.ifs[1]
            if true
              'a'
            elsif false
              'b'
            else
              'c'
            end
          end
        end
      end
      CRYSTAL

    it "inherits a logic from `NodeVisitor`" do
      subject.should be_a(NodeVisitor)
    end

    it "fires a callback for every `if` node, excluding `elsif` branches" do
      rule.ifs.size.should eq 3
    end

    it "fires a callback with an array containing an `if` node without an `elsif` branches" do
      if_node, ifs = rule.ifs[0]
      if_node.to_s.should eq "foo ? bar : baz"

      ifs.should be_nil
    end

    it "fires a callback with an array containing an `if` node with multiple `elsif` branches" do
      if_node, ifs = rule.ifs[2]
      if_node.cond.to_s.should eq ":one"

      ifs = ifs.should_not be_nil
      ifs.size.should eq 3
      ifs.first.should be if_node
      ifs.map(&.then.to_s).should eq %w[1 2 3]
    end

    it "fires a callback with an array containing an `if` node with the `else` branch as the last item" do
      if_node, ifs = rule.ifs[1]
      if_node.cond.to_s.should eq "true"

      ifs = ifs.should_not be_nil
      ifs.size.should eq 2
      ifs.first.should be if_node
      ifs.map(&.then.to_s).should eq %w['a' 'b']
      ifs.last.else.to_s.should eq %('c')
    end
  end
end
