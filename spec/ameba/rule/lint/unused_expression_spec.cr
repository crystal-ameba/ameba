require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedExpression do
    subject = UnusedExpression.new

    context "class variable access" do
      it "passes if class variables are used for assignment" do
        expect_no_issues subject, <<-CRYSTAL
          class MyClass
            foo = @@ivar
          end
          CRYSTAL
      end

      it "passes if an class variable is used as a target in multi-assignment" do
        expect_no_issues subject, <<-CRYSTAL
          class MyClass
            @@foo, @@bar = 1, 2
          end
          CRYSTAL
      end

      it "fails if class variables are unused in void context of class" do
        expect_issue subject, <<-CRYSTAL
          class Actor
            @@name : String = "George"

            @@name
          # ^^^^^^ error: Class variable access is unused
          end
          CRYSTAL
      end

      it "fails if class variables are unused in void context of method" do
        expect_issue subject, <<-'CRYSTAL'
          def hello : String
            @@name
          # ^^^^^^ error: Class variable access is unused

            "Hello, #{@@name}!"
          end
          CRYSTAL
      end
    end

    context "comparison" do
      it "passes if comparison used in assign" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 1 == "1"
          bar = begin
            2 == "2"
          end
          CRYSTAL
      end

      it "passes if comparison used in if condition" do
        expect_no_issues subject, <<-CRYSTAL
          if foo == bar
            puts "baz"
          end
          CRYSTAL
      end

      it "passes if comparison implicitly returns from method body" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            1 == 2
          end
          CRYSTAL
      end

      it "passes for implicit object comparisons" do
        expect_no_issues subject, <<-CRYSTAL
          case obj
          when .> 1 then foo
          when .< 0 then bar
          end
          CRYSTAL
      end

      it "passes for comparisons inside '||' and '&&' where the other arg is a call" do
        expect_no_issues subject, <<-CRYSTAL
          foo(bar) == baz || raise "bat"
          foo(bar) == baz && raise "bat"
          CRYSTAL
      end

      it "passes for unused comparisons with `===`, `=~`, and `!~`" do
        expect_no_issues subject, <<-CRYSTAL
          /foo(bar)?/ =~ baz
          /foo(bar)?/ !~ baz
          "foo" === bar
          CRYSTAL
      end

      it "fails if a comparison operation with `==` is unused" do
        expect_issue subject, <<-CRYSTAL
          foo == 2
          # ^^^^^^ error: Comparison operation is unused
          CRYSTAL
      end

      it "fails if a comparison operation with `!=` is unused" do
        expect_issue subject, <<-CRYSTAL
          foo != 2
          # ^^^^^^ error: Comparison operation is unused
          CRYSTAL
      end

      it "fails if a comparison operation with `<` is unused" do
        expect_issue subject, <<-CRYSTAL
          foo < 2
          # ^^^^^ error: Comparison operation is unused
          CRYSTAL
      end

      it "fails if a comparison operation with `<=` is unused" do
        expect_issue subject, <<-CRYSTAL
          foo <= 2
          # ^^^^^^ error: Comparison operation is unused
          CRYSTAL
      end

      it "fails if a comparison operation with `>` is unused" do
        expect_issue subject, <<-CRYSTAL
          foo > 2
          # ^^^^^ error: Comparison operation is unused
          CRYSTAL
      end

      it "fails if a comparison operation with `>=` is unused" do
        expect_issue subject, <<-CRYSTAL
          foo >= 2
          # ^^^^^^ error: Comparison operation is unused
          CRYSTAL
      end

      it "fails if a comparison operation with `<=>` is unused" do
        expect_issue subject, <<-CRYSTAL
          foo <=> 2
          # ^^^^^^^ error: Comparison operation is unused
          CRYSTAL
      end

      it "fails for an unused comparison in a begin block" do
        expect_issue subject, <<-CRYSTAL
          begin
            x = 1
            x == 2
          # ^^^^^^ error: Comparison operation is unused
            puts x
          end
          CRYSTAL
      end

      it "fails for unused comparisons in if/elsif/else bodies" do
        expect_issue subject, <<-CRYSTAL
          a = if x = 1
                x == 1
              # ^^^^^^ error: Comparison operation is unused
                x == 2
              elsif true
                x == 1
              # ^^^^^^ error: Comparison operation is unused
                x == 2
              else
                x == 2
              # ^^^^^^ error: Comparison operation is unused
                x == 3
              end
          CRYSTAL
      end

      it "fails for unused comparisons in a proc body" do
        expect_issue subject, <<-CRYSTAL
          a = -> do
            x == 1
          # ^^^^^^ error: Comparison operation is unused
            "meow"
          end
          CRYSTAL
      end

      it "fails for unused comparison in top-level if statement body" do
        expect_issue subject, <<-CRYSTAL
          if true
            x == 1
          # ^^^^^^ error: Comparison operation is unused
          else
            x == 2
          # ^^^^^^ error: Comparison operation is unused
          end
          CRYSTAL
      end

      it "fails for unused comparison in void of method body" do
        expect_issue subject, <<-CRYSTAL
          def foo
            if x == 3
              x < 1
            # ^^^^^ error: Comparison operation is unused
            else
              x > 1
            # ^^^^^ error: Comparison operation is unused
            end

            return
          end
          CRYSTAL
      end
    end

    context "generic or union" do
      it "passes if a generic is used in a top-level type declaration" do
        expect_no_issues subject, <<-CRYSTAL
          foo : Bar?
          CRYSTAL
      end

      it "passes if a union is used in a top-level type declaration" do
        expect_no_issues subject, <<-CRYSTAL
          foo : Bar | Baz
          CRYSTAL
      end

      it "passes if a generic is used in an assign" do
        expect_no_issues subject, <<-CRYSTAL
          foo = Bar?
          CRYSTAL
      end

      it "passes if a union is used in an assign" do
        expect_no_issues subject, <<-CRYSTAL
          foo = Bar | Baz
          CRYSTAL
      end

      it "passes if a generic or union is used in a cast" do
        expect_no_issues subject, <<-CRYSTAL
          bar = foo.as(Bar?)
          baz = bar.as?(Baz | Qux)
          CRYSTAL
      end

      it "passes if a generic or union is used as a method argument" do
        expect_no_issues subject, <<-CRYSTAL
          puts StaticArray(Int32, 10)
          CRYSTAL
      end

      it "passes if a generic is used as a method call object" do
        expect_no_issues subject, <<-CRYSTAL
          MyClass(String).new
          CRYSTAL
      end

      it "passes if something that looks like a union but isn't is top-level" do
        expect_no_issues subject, <<-CRYSTAL
          # Not a union
          Foo | "Bar"
          CRYSTAL
      end

      it "passes for an unused path" do
        expect_no_issues subject, "Foo"
      end

      it "passes if a generic is used for a parameter type restriction" do
        expect_no_issues subject, <<-CRYSTAL
          def foo(bar : Baz?)
          end
          CRYSTAL
      end

      it "passes if a generic is used for a method return type restriction" do
        expect_no_issues subject, <<-CRYSTAL
          def foo : Baz?
          end
          CRYSTAL
      end

      it "passes if a union is used for a parameter type restriction" do
        expect_no_issues subject, <<-CRYSTAL
          def foo(bar : Baz | Qux)
          end
          CRYSTAL
      end

      it "passes if a union is used for a method return type restriction" do
        expect_no_issues subject, <<-CRYSTAL
          def foo : Baz | Qux
          end
          CRYSTAL
      end

      it "fails for an unused top-level generic" do
        expect_issue subject, <<-CRYSTAL
          String?
          # ^^^^^ error: Generic type is unused
          StaticArray(Int32, 10)
          # ^^^^^^^^^^^^^^^^^^^^ error: Generic type is unused
          CRYSTAL
      end

      it "fails for an unused top-level union" do
        expect_issue subject, <<-CRYSTAL
          Int32 | Float64 | Nil
          # ^^^^^^^^^^^^^^^^^^^ error: Union type is unused
          CRYSTAL
      end

      it "fails for an unused top-level union of self, typeof, and underscore" do
        expect_issue subject, <<-CRYSTAL
          self | typeof(1) | _
          # ^^^^^^^^^^^^^^^^^^ error: Union type is unused
          CRYSTAL
      end

      it "fails if a generic is in void of method body" do
        expect_issue subject, <<-CRYSTAL
          def foo
            Float64?
          # ^^^^^^^^ error: Generic type is unused
            nil
          end
          CRYSTAL
      end

      it "fails if a union is in void of method body" do
        expect_issue subject, <<-CRYSTAL
          def foo
            Bar | Baz
          # ^^^^^^^^^ error: Union type is unused
            nil
          end
          CRYSTAL
      end

      it "fails if a generic is in void of class body" do
        expect_issue subject, <<-CRYSTAL
          class MyClass
            String?
          # ^^^^^^^ error: Generic type is unused
          end
          CRYSTAL
      end
    end

    context "instance variable access" do
      it "passes if instance variables are used for assignment" do
        expect_no_issues subject, <<-CRYSTAL
          class MyClass
            foo = @ivar
          end
          CRYSTAL
      end

      it "passes if an instance variable is used as a target in multi-assignment" do
        expect_no_issues subject, <<-CRYSTAL
          class MyClass
            @foo, @bar = 1, 2
          end
          CRYSTAL
      end

      it "fails if instance variables are unused in void context of class" do
        expect_issue subject, <<-CRYSTAL
          class Actor
            @name : String = "George"

            @name
          # ^^^^^ error: Instance variable access is unused
          end
          CRYSTAL
      end

      it "fails if instance variables are unused in void context of method" do
        expect_issue subject, <<-'CRYSTAL'
          def hello : String
            @name
          # ^^^^^ error: Instance variable access is unused

            "Hello, #{@name}!"
          end
          CRYSTAL
      end

      it "passes if @type is unused within a macro expression" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            {% @type %}
            :bar
          end
          CRYSTAL
      end

      it "fails if instance variable is unused within a macro expression" do
        expect_issue subject, <<-CRYSTAL
          def foo
            {% @bar %}
             # ^^^^ error: Instance variable access is unused
            :baz
          end
          CRYSTAL
      end
    end

    context "literal" do
      it "passes if a number literal is used to assign" do
        expect_no_issues subject, <<-CRYSTAL
          a = 1
          CRYSTAL
      end

      it "passes if a char literal is used to assign" do
        expect_no_issues subject, <<-'CRYSTAL'
          c = '\t'
          CRYSTAL
      end

      it "passes if a string literal is used to assign" do
        expect_no_issues subject, <<-'CRYSTAL'
          b = "foo"
          g = "bar #{baz}"
          CRYSTAL
      end

      it "passes if a heredoc is used to assign" do
        expect_no_issues subject, <<-CRYSTAL
          h = <<-HEREDOC
            foo
            HEREDOC
          CRYSTAL
      end

      it "passes if a symbol literal is used to assign" do
        expect_no_issues subject, <<-CRYSTAL
          c = :foo
          CRYSTAL
      end

      it "passes if a named tuple literal is used to assign" do
        expect_no_issues subject, <<-CRYSTAL
          d = {foo: 1, bar: 2}
          CRYSTAL
      end

      it "passes if an array literal is used to assign" do
        expect_no_issues subject, <<-CRYSTAL
          e = [10_f32, 20_f32, 30_f32]
          CRYSTAL
      end

      it "passes if a proc literal is used to assign" do
        expect_no_issues subject, <<-CRYSTAL
          f = -> { }
          CRYSTAL
      end

      it "passes if literals inside an if statement are implicitly returned from a method" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            if true
              :bar
            else
              "baz"
            end
          end
          CRYSTAL
      end

      it "passes if an unused literal is beyond a return statement in a method body" do
        expect_no_issues subject, <<-CRYSTAL
          def foo : Nil
            return
            :bar
            nil
          end
          CRYSTAL
      end

      it "passes if a literal is the object of a call" do
        expect_no_issues subject, <<-CRYSTAL
          { foo: "bar" }.to_json(io)
          CRYSTAL
      end

      it "passes for a literal in a generic type" do
        expect_no_issues subject, <<-CRYSTAL
          foo = StaticArray(Int32, 3)
          bar = Int32[3]
          CRYSTAL
      end

      it "passes if a literal is passed to with or yield" do
        expect_no_issues subject, <<-CRYSTAL
          yield 1
          with "2" yield :three
          CRYSTAL
      end

      it "passes if a literal value is the object of a cast" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 1.as(Int64)
          bar = "2".as?(String)
          CRYSTAL
      end

      it "passes if a literal value is the object of a cast" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 1.as(Int64)
          bar = "2".as?(String)
          CRYSTAL
      end

      it "fails if a number literal is top-level" do
        expect_issue subject, <<-CRYSTAL
          1234
          # ^^ error: Literal value is unused
          1234_f32
          # ^^^^^^ error: Literal value is unused
          CRYSTAL
      end

      it "fails if a string literal is top-level" do
        expect_issue subject, <<-'CRYSTAL'
          "hello world"
          # ^^^^^^^^^^^ error: Literal value is unused
          "foo #{bar}"
          # ^^^^^^^^^^ error: Literal value is unused
          CRYSTAL
      end

      it "fails if an array literal is top-level" do
        expect_issue subject, <<-CRYSTAL
          [1, 2, 3, 4, 5]
          # ^^^^^^^^^^^^^ error: Literal value is unused
          CRYSTAL
      end

      it "fails if a hash literal is top-level" do
        expect_issue subject, <<-CRYSTAL
          {"foo" => "bar"}
          # ^^^^^^^^^^^^^^ error: Literal value is unused
          CRYSTAL
      end

      it "fails if a char literal is top-level" do
        expect_issue subject, <<-'CRYSTAL'
          '\t'
          # ^^ error: Literal value is unused
          CRYSTAL
      end

      it "fails if a range literal is top-level" do
        expect_issue subject, <<-CRYSTAL
          1..2
          # ^^ error: Literal value is unused
          CRYSTAL
      end

      it "fails if a tuple literal is top-level" do
        expect_issue subject, <<-CRYSTAL
          {1, 2, 3}
          # ^^^^^^^ error: Literal value is unused
          CRYSTAL
      end

      it "fails if a named tuple literal is top-level" do
        expect_issue subject, <<-CRYSTAL
          {foo: bar}
          # ^^^^^^^^ error: Literal value is unused
          CRYSTAL
      end

      it "fails if a heredoc is top-level" do
        expect_issue subject, <<-CRYSTAL
          <<-HEREDOC
          # ^^^^^^^^ error: Literal value is unused
            this is a heredoc
            HEREDOC
          CRYSTAL
      end

      it "fails if a number literal is in void of method body" do
        expect_issue subject, <<-CRYSTAL
          def foo
            1234
          # ^^^^ error: Literal value is unused
            1234_f32
          # ^^^^^^^^ error: Literal value is unused
            return
          end
          CRYSTAL
      end

      it "fails if a string literal is in void of method body" do
        expect_issue subject, <<-'CRYSTAL'
          def foo
            "hello world"
          # ^^^^^^^^^^^^^ error: Literal value is unused
            "foo #{bar}"
          # ^^^^^^^^^^^^ error: Literal value is unused
            return
          end
          CRYSTAL
      end

      it "fails if an array literal is in void of method body" do
        expect_issue subject, <<-CRYSTAL
          def foo
            [1, 2, 3, 4, 5]
          # ^^^^^^^^^^^^^^^ error: Literal value is unused
            return
          end
          CRYSTAL
      end

      it "fails if a hash literal is in void of method body" do
        expect_issue subject, <<-CRYSTAL
          def foo
            {"foo" => "bar"}
          # ^^^^^^^^^^^^^^^^ error: Literal value is unused
            return
          end
          CRYSTAL
      end

      it "fails if a char literal is in void of method body" do
        expect_issue subject, <<-'CRYSTAL'
          def foo
            '\t'
          # ^^^^ error: Literal value is unused
            return
          end
          CRYSTAL
      end

      it "fails if a range literal is in void of method body" do
        expect_issue subject, <<-CRYSTAL
          def foo
            1..2
          # ^^^^ error: Literal value is unused
            return
          end
          CRYSTAL
      end

      it "fails if a tuple literal is in void of method body" do
        expect_issue subject, <<-CRYSTAL
          def foo
            {1, 2, 3}
          # ^^^^^^^^^ error: Literal value is unused
            return
          end
          CRYSTAL
      end

      it "fails if a named tuple literal is in void of method body" do
        expect_issue subject, <<-CRYSTAL
          def foo
            {foo: bar}
          # ^^^^^^^^^^ error: Literal value is unused
            return
          end
          CRYSTAL
      end

      it "fails if a heredoc is in void of method body" do
        expect_issue subject, <<-CRYSTAL
          def foo
            <<-HEREDOC
          # ^^^^^^^^^^ error: Literal value is unused
              this is a heredoc
              HEREDOC
            return
          end
          CRYSTAL
      end

      it "fails if a number literal is in void of if statement body" do
        expect_issue subject, <<-CRYSTAL
          if true
            1234
          # ^^^^ error: Literal value is unused
            1234_f32
          # ^^^^^^^^ error: Literal value is unused
            nil
          end
          CRYSTAL
      end

      it "fails if a string literal is in void of if statement body" do
        expect_issue subject, <<-'CRYSTAL'
          if true
            "hello world"
          # ^^^^^^^^^^^^^ error: Literal value is unused
            "foo #{bar}"
          # ^^^^^^^^^^^^ error: Literal value is unused
            nil
          end
          CRYSTAL
      end

      it "fails if an array literal is in void of if statement body" do
        expect_issue subject, <<-CRYSTAL
          if true
            [1, 2, 3, 4, 5]
          # ^^^^^^^^^^^^^^^ error: Literal value is unused
            nil
          end
          CRYSTAL
      end

      it "fails if a hash literal is in void of if statement body" do
        expect_issue subject, <<-CRYSTAL
          if true
            {"foo" => "bar"}
          # ^^^^^^^^^^^^^^^^ error: Literal value is unused
            nil
          end
          CRYSTAL
      end

      it "fails if a char literal is in void of if statement body" do
        expect_issue subject, <<-'CRYSTAL'
          if true
            '\t'
          # ^^^^ error: Literal value is unused
            nil
          end
          CRYSTAL
      end

      it "fails if a range literal is in void of if statement body" do
        expect_issue subject, <<-CRYSTAL
          if true
            1..2
          # ^^^^ error: Literal value is unused
            nil
          end
          CRYSTAL
      end

      it "fails if a tuple literal is in void of if statement body" do
        expect_issue subject, <<-CRYSTAL
          if true
            {1, 2, 3}
          # ^^^^^^^^^ error: Literal value is unused
            nil
          end
          CRYSTAL
      end

      it "fails if a named tuple literal is in void of if statement body" do
        expect_issue subject, <<-CRYSTAL
          if true
            {foo: bar}
          # ^^^^^^^^^^ error: Literal value is unused
            nil
          end
          CRYSTAL
      end

      it "fails if a heredoc is in void of if statement body" do
        expect_issue subject, <<-CRYSTAL
          if true
            <<-HEREDOC
          # ^^^^^^^^^^ error: Literal value is unused
              this is a heredoc
              HEREDOC
            nil
          end
          CRYSTAL
      end

      it "fails if an unused literal is in begin or ensure body" do
        expect_issue subject, <<-CRYSTAL
          a = begin
                1234
              # ^^^^ error: Literal value is unused
              rescue Foo
                1234
              else
                1234
              ensure
                1234
              # ^^^^ error: Literal value is unused
              end
          CRYSTAL
      end

      it "fails if an unused literal is in void of class body" do
        expect_issue subject, <<-CRYSTAL
          class MyClass
            1234
          # ^^^^ error: Literal value is unused
          end
          CRYSTAL
      end

      it "passes if an unused method call is the last line of a method with a Nil return type restriction" do
        expect_no_issues subject, <<-CRYSTAL
          def foo : Nil
            bar("baz")
          end
          CRYSTAL
      end

      it "fails if an unused literal is the last line of a method with a Nil return type restriction" do
        expect_issue subject, <<-CRYSTAL
          def foo : Nil
            1234
          # ^^^^ error: Literal value is unused
          end
          CRYSTAL
      end

      it "fails if an unused literal is the last line of an initialize method" do
        expect_issue subject, <<-CRYSTAL
          def initialize
            1234
          # ^^^^ error: Literal value is unused
          end
          CRYSTAL
      end

      it "passes if a literal is used in outputting macro expression" do
        expect_no_issues subject, <<-CRYSTAL
          {{ "foo" }}
          CRYSTAL
      end

      it "fails if a literal is used in non-outputting macro expression" do
        expect_issue subject, <<-CRYSTAL
          {% "foo" %}
           # ^^^^^ error: Literal value is unused
          CRYSTAL
      end

      it "fails if a literal is unused in macro expressions inside of a macro if" do
        expect_issue subject, <<-CRYSTAL
          {% if true %}
            {% "foo" %}
             # ^^^^^ error: Literal value is unused
          {% end %}
          CRYSTAL
      end

      it "fails if a literal is unused in macro expressions inside of a macro for" do
        expect_issue subject, <<-CRYSTAL
          {% for i in [1, 2, 3] %}
            {% "foo" %}
             # ^^^^^ error: Literal value is unused
          {% end %}
          CRYSTAL
      end

      it "fails if a literal is unused in macro defs" do
        expect_issue subject, <<-CRYSTAL
          macro name(foo)
            {% "bar" %}
             # ^^^^^ error: Literal value is unused
          end
          CRYSTAL
      end

      it "fails if a regex literal is unused" do
        expect_issue subject, <<-'CRYSTAL'
          foo = /hello world/
          /goodnight moon/
          # ^^^^^^^^^^^^^^ error: Literal value is unused
          bar = /goodnight moon, #{foo}/
          /goodnight moon, #{foo}/
          # ^^^^^^^^^^^^^^^^^^^^^^ error: Literal value is unused
          CRYSTAL
      end
    end

    context "local variable access" do
      it "passes if local variables are used in assign" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 1
          foo += 1
          foo, bar = 2, 3
          CRYSTAL
      end

      it "passes if a local variable is a call argument" do
        expect_no_issues subject, <<-CRYSTAL
          foo = 1
          puts foo
          CRYSTAL
      end

      it "passes if local variable on left side of a comparison" do
        expect_no_issues subject, <<-CRYSTAL
          def hello
            foo = 1
            foo || (puts "foo is falsey")
            foo
          end
          CRYSTAL
      end

      it "passes if skip_file is used in a macro" do
        expect_no_issues subject, <<-CRYSTAL
          {% skip_file %}
          CRYSTAL
      end

      it "passes if debug is used in a macro" do
        expect_no_issues subject, <<-CRYSTAL
          {% debug %}
          CRYSTAL
      end

      it "fails if a local variable is in a void context" do
        expect_issue subject, <<-CRYSTAL
          foo = 1

          begin
            foo
          # ^^^ error: Local variable access is unused
            puts foo
          end
          CRYSTAL
      end

      it "fails if a parameter is in a void context" do
        expect_issue subject, <<-CRYSTAL
          def foo(bar)
            if bar > 0
              bar
            # ^^^ error: Local variable access is unused
            end

            nil
          end
          CRYSTAL
      end
    end

    context "pseudo-method call" do
      it "passes if typeof is unused" do
        expect_no_issues subject, <<-CRYSTAL
          typeof(1)
          CRYSTAL
      end

      it "passes if as is unused" do
        expect_no_issues subject, <<-CRYSTAL
          as(Int32)
          CRYSTAL
      end

      it "fails if pointerof is unused" do
        expect_issue subject, <<-CRYSTAL
          pointerof(Int32)
          # ^^^^^^^^^^^^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if sizeof is unused" do
        expect_issue subject, <<-CRYSTAL
          sizeof(Int32)
          # ^^^^^^^^^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if instance_sizeof is unused" do
        expect_issue subject, <<-CRYSTAL
          instance_sizeof(Int32)
          # ^^^^^^^^^^^^^^^^^^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if alignof is unused" do
        expect_issue subject, <<-CRYSTAL
          alignof(Int32)
          # ^^^^^^^^^^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if instance_alignof is unused" do
        expect_issue subject, <<-CRYSTAL
          instance_alignof(Int32)
          # ^^^^^^^^^^^^^^^^^^^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if offsetof is unused" do
        expect_issue subject, <<-CRYSTAL
          offsetof(Int32, 1)
          # ^^^^^^^^^^^^^^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if is_a? is unused" do
        expect_issue subject, <<-CRYSTAL
          foo = 1
          foo.is_a?(Int32)
          # ^^^^^^^^^^^^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if as? is unused" do
        expect_issue subject, <<-CRYSTAL
          foo = 1
          foo.as?(Int32)
          # ^^^^^^^^^^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if responds_to? is unused" do
        expect_issue subject, <<-CRYSTAL
          foo = 1
          foo.responds_to?(:bar)
          # ^^^^^^^^^^^^^^^^^^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if nil? is unused" do
        expect_issue subject, <<-CRYSTAL
          foo = 1
          foo.nil?
          # ^^^^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if prefix not is unused" do
        expect_issue subject, <<-CRYSTAL
          foo = 1
          !foo
          # ^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "fails if suffix not is unused" do
        expect_issue subject, <<-CRYSTAL
          foo = 1
          foo.!
          # ^^^ error: Pseudo-method call is unused
          CRYSTAL
      end

      it "passes if pointerof is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = pointerof(Int32)
          CRYSTAL
      end

      it "passes if sizeof is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = sizeof(Int32)
          CRYSTAL
      end

      it "passes if instance_sizeof is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = instance_sizeof(Int32)
          CRYSTAL
      end

      it "passes if alignof is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = alignof(Int32)
          CRYSTAL
      end

      it "passes if instance_alignof is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = instance_alignof(Int32)
          CRYSTAL
      end

      it "passes if offsetof is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = offsetof(Int32, 1)
          CRYSTAL
      end

      it "passes if is_a? is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = is_a?(Int32)
          CRYSTAL
      end

      it "passes if as? is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = as?(Int32)
          CRYSTAL
      end

      it "passes if responds_to? is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = responds_to?(:foo)
          CRYSTAL
      end

      it "passes if nil? is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = nil?
          CRYSTAL
      end

      it "passes if prefix not is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = !true
          CRYSTAL
      end

      it "passes if suffix not is used as an assign value" do
        expect_no_issues subject, <<-CRYSTAL
          var = true.!
          CRYSTAL
      end
    end

    context "self access" do
      it "passes if self is used as receiver for a method def" do
        expect_no_issues subject, <<-CRYSTAL
          def self.foo
          end
          CRYSTAL
      end

      it "passes if self is used as object of call" do
        expect_no_issues subject, <<-CRYSTAL
          self.foo
          CRYSTAL
      end

      it "passes if self is used as method of call" do
        expect_no_issues subject, <<-CRYSTAL
          foo.self
          CRYSTAL
      end

      it "fails if self is unused in void context of class body" do
        expect_issue subject, <<-CRYSTAL
          class MyClass
            self
          # ^^^^ error: `self` access is unused
          end
          CRYSTAL
      end

      it "fails if self is unused in void context of begin" do
        expect_issue subject, <<-CRYSTAL
          begin
            self
          # ^^^^ error: `self` access is unused

            break
          end
          CRYSTAL
      end

      it "fails if self is unused in void context of method def" do
        expect_issue subject, <<-CRYSTAL
          def foo
            self
          # ^^^^ error: `self` access is unused
            "bar"
          end
          CRYSTAL
      end
    end
  end
end
