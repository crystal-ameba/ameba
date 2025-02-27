require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedLiteral do
    subject = UnusedLiteral.new

    it "passes if a number literal is used to assign" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1
        CRYSTAL
    end

    it "passes if a char literal is used to assign" do
      expect_no_issues subject, <<-CRYSTAL
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
        StaticArray(Int32, 3)
        Int32[3]
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
        1.as(Int64)
        "2".as?(String)
        CRYSTAL
    end

    it "passes if a literal value is the object of a cast" do
      expect_no_issues subject, <<-CRYSTAL
        1.as(Int64)
        "2".as?(String)
        CRYSTAL
    end

    it "fails if a number literal is top-level" do
      expect_issue subject, <<-CRYSTAL
        1234
        # ^^ error: Literal value is not used
        1234_f32
        # ^^^^^^ error: Literal value is not used
        CRYSTAL
    end

    it "fails if a string literal is top-level" do
      expect_issue subject, <<-'CRYSTAL'
        "hello world"
        # ^^^^^^^^^^^ error: Literal value is not used
        "interp #{string}"
        # ^^^^^^^^^^^^^^^^ error: Literal value is not used
        CRYSTAL
    end

    it "fails if an array literal is top-level" do
      expect_issue subject, <<-CRYSTAL
        [1, 2, 3, 4, 5]
        # ^^^^^^^^^^^^^ error: Literal value is not used
        CRYSTAL
    end

    it "fails if a hash literal is top-level" do
      expect_issue subject, <<-CRYSTAL
        {"foo" => "bar"}
        # ^^^^^^^^^^^^^^ error: Literal value is not used
        CRYSTAL
    end

    it "fails if a char literal is top-level" do
      expect_issue subject, <<-CRYSTAL
        '\t'
        # ^ error: Literal value is not used
        CRYSTAL
    end

    it "fails if a range literal is top-level" do
      expect_issue subject, <<-CRYSTAL
        1..2
        # ^^ error: Literal value is not used
        CRYSTAL
    end

    it "fails if a tuple literal is top-level" do
      expect_issue subject, <<-CRYSTAL
        {1, 2, 3}
        # ^^^^^^^ error: Literal value is not used
        CRYSTAL
    end

    it "fails if a named tuple literal is top-level" do
      expect_issue subject, <<-CRYSTAL
        {foo: bar}
        # ^^^^^^^^ error: Literal value is not used
        CRYSTAL
    end

    it "fails if a heredoc is top-level" do
      expect_issue subject, <<-CRYSTAL
        <<-HEREDOC
        # ^^^^^^^^ error: Literal value is not used
          this is a heredoc
          HEREDOC
        CRYSTAL
    end

    it "fails if a number literal is in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          1234
        # ^^^^ error: Literal value is not used
          1234_f32
        # ^^^^^^^^ error: Literal value is not used
          return
        end
        CRYSTAL
    end

    it "fails if a string literal is in void of method body" do
      expect_issue subject, <<-'CRYSTAL'
        def foo
          "hello world"
        # ^^^^^^^^^^^^^ error: Literal value is not used
          "interp #{string}"
        # ^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          return
        end
        CRYSTAL
    end

    it "fails if an array literal is in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          [1, 2, 3, 4, 5]
        # ^^^^^^^^^^^^^^^ error: Literal value is not used
          return
        end
        CRYSTAL
    end

    it "fails if a hash literal is in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          {"foo" => "bar"}
        # ^^^^^^^^^^^^^^^^ error: Literal value is not used
          return
        end
        CRYSTAL
    end

    it "fails if a char literal is in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          '\t'
        # ^^^ error: Literal value is not used
          return
        end
        CRYSTAL
    end

    it "fails if a range literal is in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          1..2
        # ^^^^ error: Literal value is not used
          return
        end
        CRYSTAL
    end

    it "fails if a tuple literal is in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          {1, 2, 3}
        # ^^^^^^^^^ error: Literal value is not used
          return
        end
        CRYSTAL
    end

    it "fails if a named tuple literal is in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          {foo: bar}
        # ^^^^^^^^^^ error: Literal value is not used
          return
        end
        CRYSTAL
    end

    it "fails if a heredoc is in void of method body" do
      expect_issue subject, <<-CRYSTAL
        def foo
          <<-HEREDOC
        # ^^^^^^^^^^ error: Literal value is not used
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
        # ^^^^ error: Literal value is not used
          1234_f32
        # ^^^^^^^^ error: Literal value is not used
          nil
        end
        CRYSTAL
    end

    it "fails if a string literal is in void of if statement body" do
      expect_issue subject, <<-'CRYSTAL'
        if true
          "hello world"
        # ^^^^^^^^^^^^^ error: Literal value is not used
          "interp #{string}"
        # ^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          nil
        end
        CRYSTAL
    end

    it "fails if an array literal is in void of if statement body" do
      expect_issue subject, <<-CRYSTAL
        if true
          [1, 2, 3, 4, 5]
        # ^^^^^^^^^^^^^^^ error: Literal value is not used
          nil
        end
        CRYSTAL
    end

    it "fails if a hash literal is in void of if statement body" do
      expect_issue subject, <<-CRYSTAL
        if true
          {"foo" => "bar"}
        # ^^^^^^^^^^^^^^^^ error: Literal value is not used
          nil
        end
        CRYSTAL
    end

    it "fails if a char literal is in void of if statement body" do
      expect_issue subject, <<-CRYSTAL
        if true
          '\t'
        # ^^^ error: Literal value is not used
          nil
        end
        CRYSTAL
    end

    it "fails if a range literal is in void of if statement body" do
      expect_issue subject, <<-CRYSTAL
        if true
          1..2
        # ^^^^ error: Literal value is not used
          nil
        end
        CRYSTAL
    end

    it "fails if a tuple literal is in void of if statement body" do
      expect_issue subject, <<-CRYSTAL
        if true
          {1, 2, 3}
        # ^^^^^^^^^ error: Literal value is not used
          nil
        end
        CRYSTAL
    end

    it "fails if a named tuple literal is in void of if statement body" do
      expect_issue subject, <<-CRYSTAL
        if true
          {foo: bar}
        # ^^^^^^^^^^ error: Literal value is not used
          nil
        end
        CRYSTAL
    end

    it "fails if a heredoc is in void of if statement body" do
      expect_issue subject, <<-CRYSTAL
        if true
          <<-HEREDOC
        # ^^^^^^^^^^ error: Literal value is not used
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
            # ^^^^ error: Literal value is not used
            rescue Foo
              1234
            else
              1234
            ensure
              1234
            # ^^^^ error: Literal value is not used
            end
        CRYSTAL
    end

    it "fails if an unused literal is in void of class body" do
      expect_issue subject, <<-CRYSTAL
        class MyClass
          1234
        # ^^^^ error: Literal value is not used
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
        # ^^^^ error: Literal value is not used
        end
        CRYSTAL
    end

    it "fails if an unused literal is the last line of an initialize method" do
      expect_issue subject, <<-CRYSTAL
        def initialize
          1234
        # ^^^^ error: Literal value is not used
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
         # ^^^^^ error: Literal value is not used
        CRYSTAL
    end

    it "fails if a literal is unused in macro expressions inside of a macro if" do
      expect_issue subject, <<-CRYSTAL
        {% if true %}
          {% "foo" %}
           # ^^^^^ error: Literal value is not used
        {% end %}
        CRYSTAL
    end

    it "fails if a literal is unused in macro expressions inside of a macro for" do
      expect_issue subject, <<-CRYSTAL
        {% for i in [1, 2, 3] %}
          {% "foo" %}
           # ^^^^^ error: Literal value is not used
        {% end %}
        CRYSTAL
    end

    it "fails if a literal is unused in macro defs" do
      expect_issue subject, <<-CRYSTAL
        macro name(foo)
          {% "bar" %}
           # ^^^^^ error: Literal value is not used
        end
        CRYSTAL
    end

    # Locations for Regex literals were added in Crystal v1.15.0
    {% if compare_versions(Crystal::VERSION, "1.15.0") >= 0 %}
      it "fails if a regex literal is unused" do
        expect_issue subject, <<-'CRYSTAL'
          a = /hello world/
          /goodnight moon/
          # ^^^^^^^^^^^^^^ error: Literal value is not used
          b = /goodnight moon, #{a}/
          /goodnight moon, #{a}/
          # ^^^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          CRYSTAL
      end
    {% else %}
      it "passes if a regex literal is unused" do
        expect_no_issues subject, <<-'CRYSTAL'
          a = /hello world/
          /goodnight moon/
          b = /goodnight moon, #{a}/
          /goodnight moon, #{a}/
          CRYSTAL
      end
    {% end %}
  end
end
