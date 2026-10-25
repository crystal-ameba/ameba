require "../../../spec_helper"

module Ameba::AST
  describe Assignment do
    node = Crystal::NilLiteral.new
    scope = Scope.new(as_node("foo = 1"))
    variable = Variable.new(Crystal::Var.new("foo"), scope)

    describe "#initialize" do
      it "creates a new assignment with node and var" do
        assignment = Assignment.new(node, variable, scope)
        assignment.node.should_not be_nil
      end
    end

    describe "#target_node" do
      it "returns the variable of the out argument" do
        call = as_node("foo(out x)").as(Crystal::Call)
        out_node = call.args.first.as(Crystal::Out)

        assignment = Assignment.new(out_node, variable, scope)
        assignment.target_node.should be(out_node.exp)
      end
    end

    describe "delegation" do
      it "delegates locations" do
        assignment = Assignment.new(node, variable, scope)
        assignment.location.should eq node.location
        assignment.end_location.should eq node.end_location
      end

      it "delegates end location to the rescue node" do
        handler = as_node(<<-CRYSTAL).as(Crystal::ExceptionHandler)
          begin
          rescue ex
            puts ex
          end
          CRYSTAL
        rescues = handler.rescues.should_not be_nil

        assignment = Assignment.new(rescues.first, variable, scope)
        location = assignment.location.should_not be_nil
        end_location = assignment.end_location.should_not be_nil

        {location.line_number, location.column_number}.should eq({2, 1})
        {end_location.line_number, end_location.column_number}.should eq({2, 9})
      end

      it "delegates to_s" do
        assignment = Assignment.new(node, variable, scope)
        assignment.to_s.should eq node.to_s
      end

      it "delegates scope" do
        assignment = Assignment.new(node, variable, scope)
        assignment.scope.should eq variable.scope
      end
    end

    describe "#address_taken_before?" do
      it "returns true only for the assignments following `pointerof`" do
        rule = ScopeRule.new
        ScopeVisitor.new rule, Source.new <<-CRYSTAL
          def foo
            a = 1
            ptr = pointerof(a)
            a = 2
          end
          CRYSTAL
        scope = rule.scopes.find!(&.def?)
        variable = scope.find_variable("a").should_not be_nil

        variable.assignments.map(&.address_taken_before?).should eq [false, true]
      end
    end
  end
end
