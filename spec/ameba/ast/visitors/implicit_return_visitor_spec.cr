require "../../../spec_helper"

private def implicit_return_visit(code)
  Ameba::ImplicitReturnRule.new.tap do |rule|
    Ameba::AST::ImplicitReturnVisitor.new rule, Ameba::Source.new(code)
  end
end

private def has_unused_expression?(rule, str)
  rule.unused_expressions.any?(&.to_s.== str)
end

private def has_unused_expression?(rule, node_type : Crystal::ASTNode.class)
  rule.unused_expressions.any?(node_type)
end

private def has_unused_call?(rule, name)
  rule.unused_expressions.any? do |node|
    node.is_a?(Crystal::Call) && node.name == name
  end
end

module Ameba::AST
  describe ImplicitReturnVisitor do
    context "Crystal::Expressions" do
      it "reports all non-last expressions as unused" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def method
            foo
            bar
            baz
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_true
        has_unused_expression?(rule, "baz").should be_false
      end

      it "does not report last expression when captured as return" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def method
            foo
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_false
      end

      it "reports non-last expression even when parent captures result" do
        rule = implicit_return_visit(<<-CRYSTAL)
          x = begin
            foo
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_false
      end

      it "stops processing after control expressions" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo
          return bar
          baz
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "baz").should be_false
      end

      it "handles nested expressions correctly" do
        rule = implicit_return_visit(<<-CRYSTAL)
          begin
            foo
            begin
              bar
              baz
            end
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_true
      end
    end

    context "assignments" do
      it "marks assigned value as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo
          x = bar
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_false
      end

      it "reports assignments when not captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def method
            x = 1
            y = 2
          end
          CRYSTAL

        assigns = rule.unused_expressions.select(Crystal::Assign)
        assigns.size.should eq 1
        assigns.first.to_s.should start_with "x ="
      end

      it "marks op-assigned values as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          x = 0
          x += foo
          bar
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "marks multi-assigned values as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          a, b = foo, bar
          baz
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
      end
    end

    context "Crystal::Call" do
      it "marks all call arguments as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo(bar, baz)
          qux
          CRYSTAL

        has_unused_expression?(rule, "bar").should be_false
        has_unused_expression?(rule, "baz").should be_false
      end

      it "reports the call itself when not captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo(1)
          bar
          CRYSTAL

        has_unused_call?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_true
      end

      it "handles method calls with blocks" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo.map { |x| x + 1 }
          bar
          CRYSTAL

        has_unused_call?(rule, "map").should be_true
        has_unused_expression?(rule, "bar").should be_true
      end
    end

    context "Crystal::If and Crystal::Unless" do
      it "marks condition as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          if foo
            bar
          else
            baz
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_true
        has_unused_expression?(rule, "baz").should be_true
      end

      it "reports if statement when not captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          if true
            1
          end
          2
          CRYSTAL

        has_unused_expression?(rule, Crystal::If).should be_true
        has_unused_expression?(rule, "1").should be_true
        has_unused_expression?(rule, "2").should be_true
      end

      it "captures last line of branches when if is captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          x = if foo
            bar
            baz
          else
            qux
          end
          CRYSTAL

        has_unused_expression?(rule, "bar").should be_true
        has_unused_expression?(rule, "baz").should be_false
        has_unused_expression?(rule, "qux").should be_false
      end
    end

    context "Crystal::While and Crystal::Until" do
      it "marks condition as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          while foo
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_true
      end

      it "does not capture loop body by default" do
        rule = implicit_return_visit(<<-CRYSTAL)
          while true
            foo
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_true
      end
    end

    context "Crystal::Case" do
      it "marks case condition as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          case foo
          when 1
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "marks when conditions as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          case x
          when foo, bar
            baz
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
      end

      it "inherits parent capture state for when bodies" do
        rule = implicit_return_visit(<<-CRYSTAL)
          result = case x
          when 1
            foo
            bar
          when 2
            baz
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
      end
    end

    context "Crystal::Def" do
      it "marks method arguments as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def method(x = foo)
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "captures method body last line by default" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def method
            foo
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_false
      end

      it "does not capture body when return type is Nil" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def method : Nil
            foo
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_true
      end

      it "does not capture body in initialize methods" do
        rule = implicit_return_visit(<<-CRYSTAL)
          class Foo
            def initialize
              foo
              bar
            end
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_true
      end

      it "handles method with complex body" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def outer
            foo
            if condition
              bar
            end
            baz
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_true
        has_unused_expression?(rule, "baz").should be_false
      end
    end

    context "literals" do
      it "marks array elements as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          [foo, bar]
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
      end

      it "marks hash values as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          {a: foo, b: bar}
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
      end

      it "marks range bounds as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo..bar
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
      end

      it "marks string interpolation expressions as captured" do
        rule = implicit_return_visit(<<-'CRYSTAL')
          "hello #{foo} world"
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "marks regex contents as captured" do
        rule = implicit_return_visit(<<-'CRYSTAL')
          /#{foo}/
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end
    end

    context "Crystal::BinaryOp" do
      it "marks left side as captured when right is a Call" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo + bar()
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "marks left side as captured when right is ControlExpression" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo || return bar
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "does not mark left side as captured for simple ops" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo + bar
          CRYSTAL

        has_unused_expression?(rule, "foo + bar").should be_true
      end
    end

    context "type operations" do
      it "marks casted object as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo.as(Bar)
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "marks tested object as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          foo.is_a?(Bar)
          baz.responds_to?(:method)
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "baz").should be_false
      end

      it "marks typeof argument as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          typeof(foo)
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "marks declared value as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          x : Int32 = foo
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end
    end

    context "Crystal::ExceptionHandler" do
      it "does not capture body last line when else is present" do
        rule = implicit_return_visit(<<-CRYSTAL)
          begin
            foo
            bar
          rescue
            baz
          else
            qux
          end
          CRYSTAL

        has_unused_expression?(rule, "bar").should be_true
      end

      it "captures body last line when no else is present" do
        rule = implicit_return_visit(<<-CRYSTAL)
          x = begin
            foo
            bar
          rescue
            baz
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_false
        has_unused_expression?(rule, "baz").should be_false
      end

      it "does not capture ensure block" do
        rule = implicit_return_visit(<<-CRYSTAL)
          begin
            foo
          ensure
            bar
            baz
          end
          CRYSTAL

        has_unused_expression?(rule, "bar").should be_true
        has_unused_expression?(rule, "baz").should be_true
      end

      it "inherits capture state for rescue bodies" do
        rule = implicit_return_visit(<<-CRYSTAL)
          x = begin
            foo
          rescue
            bar
            baz
          end
          CRYSTAL

        has_unused_expression?(rule, "bar").should be_true
        has_unused_expression?(rule, "baz").should be_false
      end
    end

    context "Crystal::Block" do
      it "inherits parent capture state for block body" do
        rule = implicit_return_visit(<<-CRYSTAL)
          [1, 2].map do |x|
            foo
            x + 1
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
      end

      it "processes block when block itself is unused" do
        rule = implicit_return_visit(<<-CRYSTAL)
          3.times do
            foo
            bar
          end
          baz
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_false
        has_unused_expression?(rule, "baz").should be_true
      end
    end

    context "Crystal::ControlExpression" do
      it "marks control expression arguments as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          return foo
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "reports the control expression itself" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def method : Nil
            return 1
          end
          CRYSTAL

        has_unused_expression?(rule, Crystal::Return).should be_true
      end

      it "handles break with value" do
        rule = implicit_return_visit(<<-CRYSTAL)
          loop do
            break foo if condition
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "handles next with value" do
        rule = implicit_return_visit(<<-CRYSTAL)
          [1, 2].each do |x|
            next foo if x == 1
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end
    end

    context "macros" do
      it "marks macro arguments as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          macro method(arg = foo)
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "captures macro body" do
        rule = implicit_return_visit(<<-CRYSTAL)
          macro method
            foo
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
      end

      it "sets in_macro flag for macro body" do
        rule = implicit_return_visit(<<-CRYSTAL)
          macro method
            {% foo %}
          end
          CRYSTAL

        # ameba:disable Performance/AnyInsteadOfPresent
        rule.macro_flags.any?.should be_true
        has_unused_expression?(rule, "foo").should be_true
      end

      it "captures output macro expressions" do
        rule = implicit_return_visit(<<-CRYSTAL)
          {{ foo }}
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "does not capture non-output macro expressions" do
        rule = implicit_return_visit(<<-CRYSTAL)
          {% foo %}
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
      end

      it "sets in_macro flag for macro expression" do
        rule = implicit_return_visit(<<-CRYSTAL)
          {% foo %}
          CRYSTAL

        # ameba:disable Performance/AnyInsteadOfPresent
        rule.macro_flags.any?.should be_true
      end

      it "marks macro if condition as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          {% if foo %}
          {% end %}
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "does not capture macro if branches" do
        rule = implicit_return_visit(<<-CRYSTAL)
          {% if true %}
            foo
          {% else %}
            bar
          {% end %}
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
      end

      it "does not capture macro for body" do
        rule = implicit_return_visit(<<-CRYSTAL)
          {% for x in [1, 2] %}
            foo
          {% end %}
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end
    end

    context "other node types" do
      it "visits enum members" do
        rule = implicit_return_visit(<<-CRYSTAL)
          enum Color
            Red
            Green
            Blue
          end
          CRYSTAL

        has_unused_expression?(rule, "Red").should be_false
        has_unused_expression?(rule, "Green").should be_false
        has_unused_expression?(rule, "Blue").should be_false
      end

      it "visits class and module bodies" do
        rule = implicit_return_visit(<<-CRYSTAL)
          class Foo
            foo
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_true
      end

      it "marks function body as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          fun foo : Int32
            return 1
          end
          CRYSTAL

        has_unused_expression?(rule, Crystal::FunDef).should be_true
      end

      it "marks unary operand as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          !foo
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "!foo").should be_true
      end

      it "marks yielded values as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          yield foo, bar
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
      end

      it "marks default argument value as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def method(x = foo)
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
      end

      it "marks annotation arguments as captured" do
        rule = implicit_return_visit(<<-CRYSTAL)
          @[Foo(bar)]
          def method
          end
          CRYSTAL

        has_unused_expression?(rule, "bar").should be_false
      end

      it "visits select whens" do
        rule = implicit_return_visit(<<-CRYSTAL)
          select
          when x = foo
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, Crystal::Select).should be_true
        has_unused_expression?(rule, "bar").should be_true
      end
    end

    context "edge cases" do
      it "handles deeply nested scopes" do
        rule = implicit_return_visit(<<-CRYSTAL)
          class Outer
            class Inner
              def method
                if true
                  foo
                  bar
                end
              end
            end
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_false
      end

      it "handles control expressions in method body" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def method
            return foo if condition
            bar
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
      end

      it "handles multiple assignment targets" do
        rule = implicit_return_visit(<<-CRYSTAL)
          a, b, c = foo, bar, baz
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
        has_unused_expression?(rule, "baz").should be_false
      end

      it "handles nested exception handlers" do
        rule = implicit_return_visit(<<-CRYSTAL)
          begin
            begin
              foo
            rescue
              bar
            end
          rescue
            baz
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_true
        has_unused_expression?(rule, "baz").should be_true
      end

      it "handles case with multiple when conditions" do
        rule = implicit_return_visit(<<-CRYSTAL)
          case x
          when foo, bar, baz
            qux
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_false
        has_unused_expression?(rule, "bar").should be_false
        has_unused_expression?(rule, "baz").should be_false
      end

      it "handles trailing control expressions" do
        rule = implicit_return_visit(<<-CRYSTAL)
          begin
            foo
            bar
            return baz
          end
          CRYSTAL

        has_unused_expression?(rule, "foo").should be_true
        has_unused_expression?(rule, "bar").should be_true
      end
    end

    context "integration scenarios" do
      it "handles complex method with multiple features" do
        rule = implicit_return_visit(<<-CRYSTAL)
          def process(items)
            return nil if items.empty?

            result = items.map do |item|
              if item.valid?
                item.process
              else
                item.skip
              end
            end

            log(result)
            result
          end
          CRYSTAL

        has_unused_call?(rule, "log").should be_true
      end

      it "handles initialize with side effects" do
        rule = implicit_return_visit(<<-CRYSTAL)
          class Foo
            def initialize(@x : Int32)
              validate!
              setup_hooks
            end
          end
          CRYSTAL

        has_unused_call?(rule, "validate!").should be_true
        has_unused_call?(rule, "setup_hooks").should be_true
      end
    end
  end
end
