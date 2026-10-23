require "../../../spec_helper"

module Ameba::Rule::Style
  describe VerboseNilType do
    subject = VerboseNilType.new

    it "passes if there are no issues" do
      expect_no_issues subject, <<-CRYSTAL
        foo : String | Number | NilableType? = nil
        bar : NilableType | String | Number? = nil
        baz : String | NilableType | Number
        bat : String?
        bun : Nil
        CRYSTAL
    end

    it "passes if the union includes metaclass (Foo.class)" do
      expect_no_issues subject, <<-CRYSTAL
        foo : Foo.class | Nil = nil
        bar : Nil | Foo.class | Bar.class
        CRYSTAL
    end

    it "corrects the verbose nil type (metaclass)" do
      source = expect_issue subject, <<-CRYSTAL
        foo : Foo.class | Bar | Nil
            # ^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bar : Nil | Bar | Foo.class
            # ^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : Foo.class | Bar?
        bar : Bar? | Foo.class
        CRYSTAL
    end

    it "reports if there is a verbose nil type (simple)" do
      source = expect_issue subject, <<-CRYSTAL
        foo : String | Nil = nil
            # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bar : Nil | String
            # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        baz : String | Nil | Int
            # ^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions

        def bat : Symbol | Nil | String
                # ^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        end

        alias Foo = Nil | Symbol
                  # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : String? = nil
        bar : String?
        baz : String | Int?

        def bat : Symbol | String?
        end

        alias Foo = Symbol?
        CRYSTAL
    end

    it "reports if there is a verbose nil type (edge-case)" do
      source = expect_issue subject, <<-CRYSTAL
        foo : String? | Nil
            # ^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bar : String | Nil?
            # ^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        baz : Nil | String? | Symbol
            # ^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : String?
        bar : String?
        baz : String | Symbol?
        CRYSTAL
    end

    it "reports if there is a verbose nil type (generics + nested unions)" do
      source = expect_issue subject, <<-CRYSTAL
        foo : (Array(String | Nil) | Nil) | Foo
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
                   # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : Array(String?) | Foo?
        CRYSTAL
    end

    it "reports if there is a verbose nil type (generics)" do
      source = expect_issue subject, <<-CRYSTAL
        foo : Array(String | Nil) | Foo
                  # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : Array(String?) | Foo
        CRYSTAL
    end

    it "corrects the verbose nil type (generics)" do
      source = expect_issue subject, <<-CRYSTAL
        foo : Array(String | Nil) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
                  # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bar : Array(String | Symbol) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        baz : Array(String) | Nil
            # ^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bat : Hash(Foo::Bar, (Baz)) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : Array(String?)?
        bar : Array(String | Symbol)?
        baz : Array(String)?
        bat : Hash(Foo::Bar, Baz)?
        CRYSTAL
    end

    it "corrects the verbose nil type (deeply nested `Nil`)" do
      source = expect_issue subject, <<-CRYSTAL
        foo : Array(Hash(String, Int32 | Nil)) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
                               # ^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bar : NamedTuple(x: String | Nil) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
                          # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        baz : (String | Nil -> Int32) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
             # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : Array(Hash(String, Int32?))?
        bar : NamedTuple(x: String?)?
        baz : (String? -> Int32)?
        CRYSTAL
    end

    it "corrects the verbose nil type (generic shorthands)" do
      source = expect_issue subject, <<-CRYSTAL
        foo : {String | Nil, Int32} | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
             # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bar : {"a b": Int32 | Nil} | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
                    # ^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        baz : (Int32 | Nil)* | Nil
            # ^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
            # ^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bat : Int32[4] | Nil
            # ^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bun : Array(String | Nil -> Int32) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
                  # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : {String?, Int32}?
        bar : {"a b": Int32?}?
        baz : Int32?*?
        bat : Int32[4]?
        bun : Array(String? -> Int32)?
        CRYSTAL
    end

    it "corrects the parenthesized single type unions" do
      source = expect_issue subject, <<-CRYSTAL
        foo : (Nil | (Symbol | Nil)) | Foo
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : Symbol | Foo?
        CRYSTAL
    end

    it "corrects the verbose nil type (metaclass within generics)" do
      source = expect_issue subject, <<-CRYSTAL
        foo : Array(Foo.class) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bar : Array(Foo.class | Nil) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : Array(Foo.class)?
        bar : Array(Foo.class | Nil)?
        CRYSTAL
    end

    it "corrects unions starting or ending with parenthesized proc notation" do
      source = expect_issue subject, <<-CRYSTAL
        foo : Nil | (String -> Int32)
            # ^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bar : (String -> Int32) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        baz : Nil | (String -> Int32) | Int32
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bat : (String ->)? | Nil
            # ^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        bun : ( String -> Int32 ) | Nil
            # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : (String -> Int32)?
        bar : (String -> Int32)?
        baz : (String -> Int32) | Int32?
        bat : (String ->)?
        bun : (String -> Int32)?
        CRYSTAL
    end

    it "does not correct multi-line unions" do
      source = expect_issue subject, <<-CRYSTAL
        alias Foo = Nil | Bool | Int64 |
                  # ^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
                    Float64 | String
        foo : String | # comment
            # ^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
              Nil
        CRYSTAL

      expect_no_corrections source
    end

    context "properties" do
      it "#explicit_nil" do
        rule = subject.class.new
        rule.explicit_nil = true

        expect_no_issues rule, <<-CRYSTAL
          foo : String | Number | Nil = nil
          bar : String | Nil
          CRYSTAL

        source = expect_issue rule, <<-CRYSTAL
          foo : String? = nil
              # ^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
          bar : String?
              # ^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          foo : String | Nil = nil
          bar : String | Nil
          CRYSTAL
      end

      it "#explicit_nil (nested unions)" do
        rule = subject.class.new
        rule.explicit_nil = true

        source = expect_issue rule, <<-CRYSTAL
          foo : String? | Int32?
              # ^^^^^^^^^^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
          bar : (String | Int32)?
              # ^^^^^^^^^^^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
          baz : Array(String?)?
              # ^^^^^^^^^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
                    # ^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          foo : String | Int32 | Nil
          bar : String | Int32 | Nil
          baz : Array(String | Nil) | Nil
          CRYSTAL

        source = expect_issue rule, <<-CRYSTAL
          foo : Foo.class | Bar?
              # ^^^^^^^^^^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
          bar : (String ->)?
              # ^^^^^^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
          baz : Nil | (String ->)?
              # ^^^^^^^^^^^^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          foo : Foo.class | Bar | Nil
          bar : (String ->) | Nil
          baz : (String ->) | Nil
          CRYSTAL
      end

      it "#only_two_element_unions" do
        rule = subject.class.new
        rule.only_two_element_unions = true

        expect_no_issues rule, <<-CRYSTAL
          foo : String | Number | Nil
          bar : String?
          baz : Nil
          CRYSTAL

        source = expect_issue rule, <<-CRYSTAL
          foo : String | Nil = nil
              # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
          bar : String | Nil
              # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
          baz : String | Number?
              # ^^^^^^^^^^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          foo : String? = nil
          bar : String?
          baz : String | Number | Nil
          CRYSTAL
      end

      it "#only_two_element_unions (nested unions)" do
        rule = subject.class.new
        rule.only_two_element_unions = true

        expect_no_issues rule, <<-CRYSTAL
          foo : (String | Nil) | Int32
          bar : Int32 | (String | Nil)
          CRYSTAL

        source = expect_issue rule, <<-CRYSTAL
          foo : String? | Nil
              # ^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
          bar : Array(String | Int32?) | Nil
              # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
                    # ^^^^^^^^^^^^^^^ error: Prefer `| Nil` instead of `?` in unions
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          foo : String?
          bar : Array(String | Int32 | Nil)?
          CRYSTAL
      end
    end
  end
end
