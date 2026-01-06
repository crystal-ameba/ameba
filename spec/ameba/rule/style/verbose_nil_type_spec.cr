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
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
             # ^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
                   # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo : (Array(String?) | Nil) | Foo
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

    it "corrects the parenthesized single type unions" do
      source = expect_issue subject, <<-CRYSTAL
        foo : (Nil | (Symbol | Nil)) | Foo
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
             # ^^^^^^^^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
                    # ^^^^^^^^^^^^ error: Prefer `?` instead of `| Nil` in unions
        CRYSTAL

      # https://github.com/crystal-lang/crystal/pull/16552
      {% if compare_versions(Crystal::VERSION, "1.19.0") >= 0 %}
        expect_correction source, <<-CRYSTAL
          foo : Symbol | Foo?
          CRYSTAL
      {% else %}
        expect_correction source, <<-CRYSTAL
          foo : (Symbol) | Foo?
          CRYSTAL
      {% end %}
    end

    context "properties" do
      it "#explicit_nil" do
        rule = VerboseNilType.new
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
    end
  end
end
