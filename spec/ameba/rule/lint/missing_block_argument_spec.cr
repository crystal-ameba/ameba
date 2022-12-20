require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = MissingBlockArgument.new

  describe MissingBlockArgument do
    it "passes if the block argument is defined" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(&)
          yield 42
        end

        def bar(&block)
          yield 24
        end

        def baz(a, b, c, &block)
          yield a, b, c
        end
        CRYSTAL
    end

    it "reports if the block argument is missing" do
      expect_issue subject, <<-CRYSTAL
        def foo
          # ^^^ error: Missing anonymous block argument. Use `&` as an argument name to indicate yielding method.
          yield 42
        end

        def bar
          # ^^^ error: Missing anonymous block argument. Use `&` as an argument name to indicate yielding method.
          yield 24
        end

        def baz(a, b, c)
          # ^^^ error: Missing anonymous block argument. Use `&` as an argument name to indicate yielding method.
          yield a, b, c
        end
        CRYSTAL
    end
  end
end
