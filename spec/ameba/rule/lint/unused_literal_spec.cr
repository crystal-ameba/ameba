require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedLiteral do
    subject = UnusedLiteral.new

    it "passes if literals are used to assign" do
      expect_no_issues subject, <<-'CRYSTAL'
        a = 1
        b = "string"
        g = "interp #{string}"
        h = <<-HEREDOC
          this is a heredoc
          HEREDOC

        c = begin
          :symbol
        end

        d = 1
        d ||= {here: 1, there: 4}

        e = [10_f32, 20_f32, 30_f32]

        f = -> { puts }
        CRYSTAL
    end

    it "passes if literals implicit return in method" do
      expect_no_issues subject, <<-CRYSTAL
        def hello
          if true
            :string
          else
            "symbol"
          end
        end
        CRYSTAL
    end

    it "passes if unused literals are beyond return" do
      expect_no_issues subject, <<-CRYSTAL
        def hello : Nil
          return :meow

          if true
            :string
          else
            "symbol"
          end
        end
        CRYSTAL
    end

    it "passes if a literal is the object of a call with args" do
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

    it "fails if literals are top-level" do
      expect_issue subject, <<-CRYSTAL
          1234
        # ^^^^ error: Literal value is not used
          1234_f32
        # ^^^^^^^^ error: Literal value is not used
          "hello world"
        # ^^^^^^^^^^^^^ error: Literal value is not used
          "interp \#{string}"
        # ^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          [1, 2, 3, 4, 5]
        # ^^^^^^^^^^^^^^^ error: Literal value is not used
          {"hello" => "world"}
        # ^^^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          '\t'
        # ^^^ error: Literal value is not used
          1..2
        # ^^^^ error: Literal value is not used
          {goodnight: moon}
        # ^^^^^^^^^^^^^^^^^ error: Literal value is not used
          {1, 2, 3}
        # ^^^^^^^^^ error: Literal value is not used
          <<-HEREDOC
        # ^^^^^^^^^^ error: Literal value is not used
            this is a heredoc
            HEREDOC
        CRYSTAL
    end

    it "fails if literals are in def body with Nil return" do
      expect_issue subject, <<-CRYSTAL
        def hello : Nil
          1234
        # ^^^^ error: Literal value is not used
          1234_f32
        # ^^^^^^^^ error: Literal value is not used
          "hello world"
        # ^^^^^^^^^^^^^ error: Literal value is not used
          "interp \#{string}"
        # ^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          [1, 2, 3, 4, 5]
        # ^^^^^^^^^^^^^^^ error: Literal value is not used
          {"hello" => "world"}
        # ^^^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          '\t'
        # ^^^ error: Literal value is not used
          1..2
        # ^^^^ error: Literal value is not used
          {goodnight: moon}
        # ^^^^^^^^^^^^^^^^^ error: Literal value is not used
          {1, 2, 3}
        # ^^^^^^^^^ error: Literal value is not used
          <<-HEREDOC
        # ^^^^^^^^^^ error: Literal value is not used
            this is a heredoc
            HEREDOC
        end
        CRYSTAL
    end

    it "fails if literals are in proc body with Nil return, alongside the proc itself" do
      expect_issue subject, <<-CRYSTAL
        -> : Nil do
        # ^^^^^^^^^ error: Literal value is not used
          1234
        # ^^^^ error: Literal value is not used
          1234_f32
        # ^^^^^^^^ error: Literal value is not used
          "hello world"
        # ^^^^^^^^^^^^^ error: Literal value is not used
          "interp \#{string}"
        # ^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          [1, 2, 3, 4, 5]
        # ^^^^^^^^^^^^^^^ error: Literal value is not used
          {"hello" => "world"}
        # ^^^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          '\t'
        # ^^^ error: Literal value is not used
          1..2
        # ^^^^ error: Literal value is not used
          {goodnight: moon}
        # ^^^^^^^^^^^^^^^^^ error: Literal value is not used
          {1, 2, 3}
        # ^^^^^^^^^ error: Literal value is not used
          <<-HEREDOC
        # ^^^^^^^^^^ error: Literal value is not used
            this is a heredoc
            HEREDOC
        end
        CRYSTAL
    end

    it "fails if literals in unused if" do
      expect_issue subject, <<-CRYSTAL
        if true
          1234
        # ^^^^ error: Literal value is not used
          1234_f32
        # ^^^^^^^^ error: Literal value is not used
          "hello world"
        # ^^^^^^^^^^^^^ error: Literal value is not used
          "interp \#{string}"
        # ^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          [1, 2, 3, 4, 5]
        # ^^^^^^^^^^^^^^^ error: Literal value is not used
          {"hello" => "world"}
        # ^^^^^^^^^^^^^^^^^^^^ error: Literal value is not used
          '\t'
        # ^^^ error: Literal value is not used
          1..2
        # ^^^^ error: Literal value is not used
          {goodnight: moon}
        # ^^^^^^^^^^^^^^^^^ error: Literal value is not used
          {1, 2, 3}
        # ^^^^^^^^^ error: Literal value is not used
          <<-HEREDOC
        # ^^^^^^^^^^ error: Literal value is not used
            this is a heredoc
            HEREDOC
        end
        CRYSTAL
    end

    it "fails if literals are unused in case" do
      expect_issue subject, <<-CRYSTAL
        thing = case object
                when Type1
                  true
                # ^^^^ error: Literal value is not used
                  "meow"
                else
                  if begin
                      "huh?"
                    # ^^^^^^ error: Literal value is not used
                      1 > 0
                    end
                    1234_f32
                  # ^^^^^^^^ error: Literal value is not used
                  end

                  "woof"
                end
        CRYSTAL
    end

    it "fails if literals are unused in class bodies" do
      expect_issue subject, <<-CRYSTAL
        class MyClass
          case object
          when Type1
            true
          # ^^^^ error: Literal value is not used
            "meow"
          # ^^^^^^ error: Literal value is not used
          else
            if begin
                "huh?"
              # ^^^^^^ error: Literal value is not used
                1 > 0
              end
              1234_f32
            # ^^^^^^^^ error: Literal value is not used
            end

            "woof"
          # ^^^^^^ error: Literal value is not used
          end
        end
        CRYSTAL
    end

    it "fails if unused literals in rescue/ensure/else block" do
      expect_issue subject, <<-CRYSTAL
        a = begin
              1234
            # ^^^^ error: Literal value is not used
              1234_f32
            # ^^^^^^^^ error: Literal value is not used
            rescue ASDF
              "hello world"
            # ^^^^^^^^^^^^^ error: Literal value is not used
              "interp \#{string}"
            rescue QWERTY
              [1, 2, 3, 4, 5]
            # ^^^^^^^^^^^^^^^ error: Literal value is not used
              {"hello" => "world"}
            else
              '\t'
            # ^^^ error: Literal value is not used
              <<-HEREDOC
            # ^^^^^^^^^^ error: Literal value is not used
                this is a heredoc
                HEREDOC
              1..2
            ensure
              {goodnight: moon}
            # ^^^^^^^^^^^^^^^^^ error: Literal value is not used
              {1, 2, 3}
            # ^^^^^^^^^ error: Literal value is not used
            end

        b = begin
              1234
            # ^^^^ error: Literal value is not used
              1234_f32
            rescue ASDF
              "hello world"
            # ^^^^^^^^^^^^^ error: Literal value is not used
              "interp \#{string}"
            ensure
              {goodnight: moon}
            # ^^^^^^^^^^^^^^^^^ error: Literal value is not used
              {1, 2, 3}
            # ^^^^^^^^^ error: Literal value is not used
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
